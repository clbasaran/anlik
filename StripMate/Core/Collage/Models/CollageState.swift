import SwiftUI

/// Per-photo pan/zoom transform. `offset` is normalized -1...1 against the
/// current overflow rectangle (kept for stability across canvas-size changes).
public struct CollagePhotoTransform: Equatable, Sendable {
    public var scale: CGFloat = 1.0
    public var offset: CGSize = .zero

    public static let identity = CollagePhotoTransform()
}

/// Single source of truth for the collage editing screen. Replaces the
/// 11-@State soup of the old CollageView.
@Observable
public final class CollageState {
    /// Photos in their final composition order.
    public private(set) var photos: [UIImage]
    /// Active preset.
    public var preset: CollagePreset
    /// Per-photo transforms keyed by index. Cleared on photo count shrink so
    /// shifted indices don't leak prior transforms onto the wrong photo.
    public var transforms: [Int: CollagePhotoTransform]

    /// User-chosen background override. nil = use preset default. Only
    /// honored when `preset.supportsBackgroundOverride` is true.
    public var backgroundOverride: CollagePreset.Style.SolidColor?

    /// Currently focused photo index (highlighted on preview, surfaces
    /// "merkeze al" reset). nil = nothing focused.
    public var focusedIndex: Int?

    /// True while a gesture is mid-drag/mid-pinch. Toggles preview between
    /// the cached bitmap and the cheap SwiftUI live canvas, so pan/zoom
    /// feels instant instead of waiting on the bitmap renderer.
    public var isInteracting: Bool = false

    /// Last rendered preview bitmap. Bound to the live preview view.
    public var renderedPreview: UIImage?
    /// True while a render is in flight.
    public var isRendering: Bool = false
    /// Monotonic generation counter — render tasks check this before
    /// committing back to `renderedPreview` so older renders that finish
    /// after a newer one was scheduled don't overwrite it.
    public private(set) var renderGeneration: Int = 0

    /// True when the user has accepted the current render (final tick).
    public var isFinalized: Bool = false

    // MARK: - Undo history

    private struct Snapshot {
        let photos: [UIImage]
        let preset: CollagePreset
        let transforms: [Int: CollagePhotoTransform]
        let backgroundOverride: CollagePreset.Style.SolidColor?
    }

    private var history: [Snapshot] = []
    private let historyLimit = 12

    public var canUndo: Bool { !history.isEmpty }

    public init(photos: [UIImage], preset: CollagePreset = .klasik) {
        self.photos = photos
        self.preset = preset
        self.transforms = [:]
        // Default to a preset that supports the photo count.
        if !preset.supportedCounts.contains(photos.count) {
            self.preset = CollagePreset.allCases.first { $0.supportedCounts.contains(photos.count) }
                ?? .klasik
        }
    }

    // MARK: - Effective style

    /// Style after applying the user's background override (if any). Renderer
    /// reads this instead of `preset.style` directly so a single source of
    /// truth controls the final look.
    public var effectiveStyle: CollagePreset.Style {
        let base = preset.style
        guard preset.supportsBackgroundOverride,
              let override = backgroundOverride,
              case .solid = base.background else { return base }
        return CollagePreset.Style(
            background: .solid(override),
            gap: base.gap,
            cornerRadius: base.cornerRadius,
            divider: base.divider
        )
    }

    // MARK: - Mutations (history-recording)

    public func addPhoto(_ image: UIImage) {
        pushHistory()
        photos.append(image)
        snapPresetToValidCount()
    }

    public func replacePhoto(at index: Int, with image: UIImage) {
        guard photos.indices.contains(index) else { return }
        pushHistory()
        photos[index] = image
        // Replacing an image invalidates that slot's transform — the new
        // photo has different dimensions/composition.
        transforms[index] = nil
    }

    public func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        pushHistory()
        photos.remove(at: index)
        // After a removal index shift, transforms can't be safely reused —
        // we'd be applying an old transform to a different photo. Drop all.
        transforms.removeAll()
        if focusedIndex == index || (focusedIndex ?? -1) >= photos.count {
            focusedIndex = nil
        }
        snapPresetToValidCount()
    }

    public func swap(_ a: Int, _ b: Int) {
        guard photos.indices.contains(a), photos.indices.contains(b), a != b else { return }
        pushHistory()
        photos.swapAt(a, b)
        let ta = transforms[a]
        let tb = transforms[b]
        transforms[a] = tb
        transforms[b] = ta
    }

    public func setPreset(_ newPreset: CollagePreset) {
        guard newPreset != preset else { return }
        pushHistory()
        preset = newPreset
        // Layout shape changes — drop transforms so they don't paint on
        // a different geometry than they were created for.
        transforms.removeAll()
        // Override only applies to solid-bg presets — clear it on switch
        // so akış doesn't ghost an override that doesn't apply.
        if !newPreset.supportsBackgroundOverride {
            backgroundOverride = nil
        }
    }

    public func setBackgroundOverride(_ override: CollagePreset.Style.SolidColor?) {
        guard preset.supportsBackgroundOverride else { return }
        guard backgroundOverride != override else { return }
        pushHistory()
        backgroundOverride = override
    }

    /// Reset a single cell's transform. Used by the focused-cell "merkeze al".
    public func resetTransform(at index: Int) {
        guard transforms[index] != nil else { return }
        pushHistory()
        transforms[index] = nil
    }

    // MARK: - Mutations (live, no history)

    /// Live transform write during an active gesture — no history push, no
    /// snapshot churn. The caller is expected to push history once at
    /// gesture start via `beginInteraction(at:)` and clear via
    /// `endInteraction()`.
    public func setTransform(_ transform: CollagePhotoTransform, at index: Int) {
        transforms[index] = transform
    }

    /// Begin a continuous gesture on a cell. Snapshots once so the whole
    /// pan/zoom counts as one undo entry, and flips into interactive mode
    /// so the screen can swap to the cheap live preview.
    public func beginInteraction(at index: Int) {
        if !isInteracting {
            pushHistory()
        }
        isInteracting = true
        focusedIndex = index
    }

    /// End the current gesture. Doesn't change transforms (caller already
    /// wrote them), just flips interactive flag so the bitmap preview
    /// re-engages.
    public func endInteraction() {
        isInteracting = false
    }

    // MARK: - Undo

    public func undo() {
        guard let snap = history.popLast() else { return }
        photos = snap.photos
        preset = snap.preset
        transforms = snap.transforms
        backgroundOverride = snap.backgroundOverride
        if (focusedIndex ?? -1) >= photos.count {
            focusedIndex = nil
        }
    }

    private func pushHistory() {
        let snap = Snapshot(
            photos: photos,
            preset: preset,
            transforms: transforms,
            backgroundOverride: backgroundOverride
        )
        history.append(snap)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    // MARK: - Render coordination

    /// Bumps the generation counter and returns the new value. Render tasks
    /// capture this and only commit if the counter is unchanged when they
    /// finish.
    public func nextRenderGeneration() -> Int {
        renderGeneration &+= 1
        return renderGeneration
    }

    /// Commit a render only if `myGeneration` is still current. Returns true
    /// when the commit was accepted.
    @discardableResult
    public func commitRender(_ image: UIImage, generation myGeneration: Int) -> Bool {
        guard myGeneration == renderGeneration else { return false }
        renderedPreview = image
        isRendering = false
        return true
    }

    // MARK: - Private

    /// Switches preset to the first one that supports the current photo
    /// count if the active preset doesn't.
    private func snapPresetToValidCount() {
        if !preset.supportedCounts.contains(photos.count) {
            preset = CollagePreset.allCases.first { $0.supportedCounts.contains(photos.count) }
                ?? preset
        }
    }
}
