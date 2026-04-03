import Foundation
import SwiftUI
import FirebaseAuth

// MARK: - Memory Period

public enum MemoryPeriod: String, CaseIterable, Identifiable {
    case week = "bu hafta"
    case month = "bu ay"
    case all = "tum zamanlar"

    public var id: String { rawValue }
}

// MARK: - Playback Speed

public enum PlaybackSpeed: String, CaseIterable, Identifiable {
    case fast = "2sn"
    case normal = "3sn"
    case slow = "5sn"

    public var id: String { rawValue }

    public var interval: TimeInterval {
        switch self {
        case .fast: return 2.0
        case .normal: return 3.0
        case .slow: return 5.0
        }
    }
}

// MARK: - DisplayLink Target

private class DisplayLinkTarget {
    var callback: (() -> Void)?
    @objc func tick(_ link: CADisplayLink) { callback?() }
}

// MARK: - MemoriesViewModel

@Observable
public final class MemoriesViewModel {
    public var photos: [PhotoMetadata] = []
    public var currentIndex: Int = 0
    public var isPlaying: Bool = true
    public var selectedPeriod: MemoryPeriod = .all
    public var filterFriendId: String?
    public var friendNameCache: [String: String] = [:]
    public var isGeneratingShare: Bool = false
    public var segmentProgress: CGFloat = 0.0
    public var playbackSpeed: PlaybackSpeed = .normal

    private var displayLink: CADisplayLink?
    private var displayLinkTarget: DisplayLinkTarget?
    private var segmentStartTime: Date?

    private var autoAdvanceInterval: TimeInterval {
        playbackSpeed.interval
    }

    public var currentPhoto: PhotoMetadata? {
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    public var progress: Double {
        guard photos.count > 1 else { return 1.0 }
        return Double(currentIndex + 1) / Double(photos.count)
    }

    // MARK: - Load Photos

    public func loadPhotos(from strips: [Strip]) {
        let calendar = Calendar.current
        let now = Date()

        let filtered: [Strip]
        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = strips.filter { $0.timestamp >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filtered = strips.filter { $0.timestamp >= monthAgo }
        case .all:
            filtered = Array(strips)
        }

        var result = filtered
        if let friendId = filterFriendId {
            result = result.filter { $0.senderId == friendId || $0.receiverIds.contains(friendId) }
        }

        // Exclude flagged and secret-locked photos
        let myId = Auth.auth().currentUser?.uid ?? ""
        result = result.filter { !$0.flagged }
        result = result.filter { strip in
            if strip.isSecret && strip.senderId != myId {
                return strip.unlockedBy.contains(myId)
            }
            return true
        }

        // Sort chronologically (oldest first for slideshow)
        result.sort { $0.timestamp < $1.timestamp }

        photos = result.map { $0.asMetadata }
        currentIndex = 0
        segmentProgress = 0
    }

    // MARK: - Timer Control (CADisplayLink)

    public func startTimer() {
        stopTimer()
        isPlaying = true
        segmentStartTime = Date()

        let target = DisplayLinkTarget()
        target.callback = { [weak self] in
            self?.handleTick()
        }
        displayLinkTarget = target

        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        isPlaying = false
    }

    private func handleTick() {
        guard let startTime = segmentStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        segmentProgress = min(CGFloat(elapsed / autoAdvanceInterval), 1.0)

        if segmentProgress >= 1.0 {
            advance()
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            // Pause: stop the display link but keep current progress
            displayLink?.invalidate()
            displayLink = nil
            displayLinkTarget = nil
            isPlaying = false
        } else {
            // Resume: adjust segmentStartTime to account for existing progress
            isPlaying = true
            let elapsedSoFar = Double(segmentProgress) * autoAdvanceInterval
            segmentStartTime = Date().addingTimeInterval(-elapsedSoFar)

            let target = DisplayLinkTarget()
            target.callback = { [weak self] in
                self?.handleTick()
            }
            displayLinkTarget = target

            let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    public func advance() {
        guard !photos.isEmpty else { return }
        segmentProgress = 0
        segmentStartTime = Date()
        currentIndex = (currentIndex + 1) % photos.count
        Task { @MainActor in HapticsManager.playImpact(style: .light) }
        if isPlaying {
            // Display link is already running, just reset timing
        }
    }

    public func goBack() {
        guard !photos.isEmpty else { return }
        segmentProgress = 0
        segmentStartTime = Date()
        currentIndex = max(0, currentIndex - 1)
        Task { @MainActor in HapticsManager.playSelection() }
    }

    public func goTo(index: Int) {
        guard index >= 0, index < photos.count else { return }
        segmentProgress = 0
        segmentStartTime = Date()
        currentIndex = index
    }

    // MARK: - Share Image Generation

    @MainActor
    public func generateShareImage() async -> UIImage? {
        isGeneratingShare = true
        defer { isGeneratingShare = false }

        let maxPhotos = min(photos.count, 6)
        guard maxPhotos > 0 else { return nil }

        let selected = Array(photos.prefix(maxPhotos))

        // Download images in parallel using TaskGroup
        let images: [UIImage] = await withTaskGroup(of: UIImage?.self, returning: [UIImage].self) { group in
            for photo in selected {
                group.addTask {
                    let urlString = photo.thumbnailUrl ?? photo.imageUrl
                    guard let url = URL(string: urlString) else { return nil }
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return UIImage(data: data)
                    } catch {
                        return nil
                    }
                }
            }
            var results: [UIImage] = []
            for await img in group {
                if let img { results.append(img) }
            }
            return results
        }

        guard !images.isEmpty else { return nil }

        // Render on background thread
        let rendered: UIImage? = await Task.detached(priority: .userInitiated) {
            let size = CGSize(width: 1080, height: 1920)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                // Black background
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))

                let columns: Int
                let rows: Int

                switch images.count {
                case 1:
                    columns = 1; rows = 1
                case 2:
                    columns = 1; rows = 2
                case 3:
                    columns = 1; rows = 3
                case 4:
                    columns = 2; rows = 2
                default:
                    columns = 2; rows = 3
                }

                let padding: CGFloat = 8
                let topPadding: CGFloat = 40
                let bottomPadding: CGFloat = 120
                let availableWidth = size.width - padding * CGFloat(columns + 1)
                let availableHeight = size.height - topPadding - bottomPadding - padding * CGFloat(rows + 1)
                let cellWidth = availableWidth / CGFloat(columns)
                let cellHeight = availableHeight / CGFloat(rows)
                let cornerRadius: CGFloat = 16

                for (index, image) in images.enumerated() {
                    let col = index % columns
                    let row = index / columns
                    guard row < rows else { break }

                    let x = padding + CGFloat(col) * (cellWidth + padding)
                    let y = topPadding + padding + CGFloat(row) * (cellHeight + padding)
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)

                    let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                    context.cgContext.saveGState()
                    path.addClip()

                    // Aspect fill
                    let imageAspect = image.size.width / image.size.height
                    let cellAspect = cellWidth / cellHeight
                    var drawRect: CGRect
                    if imageAspect > cellAspect {
                        let drawWidth = cellHeight * imageAspect
                        drawRect = CGRect(x: x - (drawWidth - cellWidth) / 2, y: y, width: drawWidth, height: cellHeight)
                    } else {
                        let drawHeight = cellWidth / imageAspect
                        drawRect = CGRect(x: x, y: y - (drawHeight - cellHeight) / 2, width: cellWidth, height: drawHeight)
                    }
                    image.draw(in: drawRect)
                    context.cgContext.restoreGState()
                }

                // Brand watermark at bottom
                let brandText = Brand.name as NSString
                let brandFont = UIFont.systemFont(ofSize: 28, weight: .bold)
                let brandAttributes: [NSAttributedString.Key: Any] = [
                    .font: brandFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.5)
                ]
                let brandSize = brandText.size(withAttributes: brandAttributes)
                let brandX = (size.width - brandSize.width) / 2
                let brandY = size.height - 70
                brandText.draw(at: CGPoint(x: brandX, y: brandY), withAttributes: brandAttributes)
            }
        }.value

        return rendered
    }

    /// Call from view's onDisappear to ensure display link is stopped
    public func onDisappear() {
        stopTimer()
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget?.callback = nil
        displayLinkTarget = nil
    }
}
