import SwiftUI

/// Collage v2 — root screen. Single-screen editing flow:
/// thumb strip + live preview + preset bar + cancel/use bar.
public struct CollageScreen: View {
    @Bindable public var state: CollageState
    public var onCancel: () -> Void
    public var onUse: (UIImage) -> Void
    public var onAddPhotoTap: () -> Void
    public var onReplacePhoto: (Int) -> Void

    @State private var renderTask: Task<Void, Never>?
    @State private var pendingPhotoTap: Int?
    @AppStorage("collage.hint.shown.v2") private var hintShown: Bool = false
    @State private var showHint: Bool = false

    public init(
        state: CollageState,
        onCancel: @escaping () -> Void,
        onUse: @escaping (UIImage) -> Void,
        onAddPhotoTap: @escaping () -> Void,
        onReplacePhoto: @escaping (Int) -> Void
    ) {
        self.state = state
        self.onCancel = onCancel
        self.onUse = onUse
        self.onAddPhotoTap = onAddPhotoTap
        self.onReplacePhoto = onReplacePhoto
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                CollageThumbStrip(
                    state: state,
                    onAddTap: onAddPhotoTap,
                    onPhotoTap: { idx in
                        HapticsManager.playSelection()
                        state.focusedIndex = (state.focusedIndex == idx) ? nil : idx
                    },
                    onPhotoLongPress: { idx in pendingPhotoTap = idx }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                CollagePreview(state: state, hintShown: hintShown)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)

                Spacer(minLength: 6)

                CollagePresetBar(state: state)
                    .padding(.bottom, 18)
            }

            if showHint {
                CollageHintOverlay(isVisible: $showHint)
                    .onChange(of: showHint) { _, newValue in
                        if !newValue { hintShown = true }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            schedule()
            if !hintShown {
                // Defer so the editor has a chance to render once before the
                // overlay appears — feels less abrupt.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    if !hintShown { withAnimation(.easeIn(duration: 0.2)) { showHint = true } }
                }
            }
        }
        .onChange(of: state.preset) { _, _ in schedule() }
        .onChange(of: state.photos.count) { _, _ in schedule() }
        .onChange(of: state.backgroundOverride) { _, _ in schedule() }
        .onChange(of: state.transforms) { _, _ in
            // While interacting we already show the live SwiftUI preview;
            // skip scheduling a bitmap render on every drag tick.
            if !state.isInteracting { schedule() }
        }
        .onChange(of: state.isInteracting) { _, isInteracting in
            // Gesture just ended — bake the final transform into a bitmap.
            if !isInteracting { schedule() }
        }
        .onDisappear { renderTask?.cancel() }
        .confirmationDialog(
            String(localized: "fotoğraf"),
            isPresented: Binding(get: { pendingPhotoTap != nil }, set: { if !$0 { pendingPhotoTap = nil } })
        ) {
            if let idx = pendingPhotoTap {
                Button(String(localized: "yeniden çek")) {
                    pendingPhotoTap = nil
                    onReplacePhoto(idx)
                }
                if (state.transforms[idx] ?? .identity) != .identity {
                    Button(String(localized: "merkeze al")) {
                        pendingPhotoTap = nil
                        state.resetTransform(at: idx)
                    }
                }
                if state.photos.count > 2 {
                    Button(String(localized: "sil"), role: .destructive) {
                        pendingPhotoTap = nil
                        state.removePhoto(at: idx)
                    }
                }
                Button(String(localized: "iptal"), role: .cancel) { pendingPhotoTap = nil }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                HapticsManager.playImpact(style: .light)
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Undo: only visible when there's history. Subtle so it doesn't
            // crowd the bar when unused.
            if state.canUndo {
                Button {
                    HapticsManager.playImpact(style: .light)
                    state.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            // Status: "X foto • presetName" replaces the empty "kolaj" title.
            VStack(spacing: 1) {
                Text("\(state.photos.count) foto · \(state.preset.displayName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                if state.isRendering && state.renderedPreview != nil {
                    Text(String(localized: "güncelleniyor…"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            useButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(Brand.Animations.fadeFast, value: state.canUndo)
    }

    @ViewBuilder
    private var useButton: some View {
        let ready = state.renderedPreview != nil && !state.isInteracting
        Button {
            guard let preview = state.renderedPreview else { return }
            HapticsManager.playNotification(type: .success)
            state.isFinalized = true
            onUse(preview)
        } label: {
            HStack(spacing: 6) {
                if !ready {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.black)
                }
                Text(ready
                     ? String(localized: "kullan")
                     : String(localized: "hazırlanıyor"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ready ? Color.white : Color.white.opacity(0.55))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .animation(Brand.Animations.fadeFast, value: ready)
    }

    // MARK: - Render scheduling

    private func schedule() {
        renderTask?.cancel()
        let myGen = state.nextRenderGeneration()
        state.isRendering = true
        let snapshot = state
        renderTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            let img = CollageRenderer.render(state: snapshot)
            guard !Task.isCancelled, let img else { return }
            await MainActor.run {
                _ = snapshot.commitRender(img, generation: myGen)
            }
        }
    }
}

// MARK: - Live Preview

private struct CollagePreview: View {
    @Bindable var state: CollageState
    let hintShown: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base layer — bitmap when ready, placeholder otherwise.
                if state.isInteracting {
                    // Drop the bitmap underneath while gesturing so it can't
                    // ghost behind the live preview.
                    Color.clear
                } else if let img = state.renderedPreview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            ProgressView()
                                .tint(.white.opacity(0.4))
                        )
                }

                // Live SwiftUI mirror — only on screen during interaction.
                if state.isInteracting {
                    CollageLivePreview(state: state)
                        .transition(.opacity)
                }

                // Focus ring for the currently-focused cell. Drawn on top
                // so it's visible against any photo content.
                if let focused = state.focusedIndex,
                   focused < state.photos.count {
                    FocusRing(state: state, focusedIndex: focused, canvasSize: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                CollageInteractiveLayer(state: state, canvasSize: geo.size)
            )
            .overlay(alignment: .bottomTrailing) {
                if let focused = state.focusedIndex,
                   (state.transforms[focused] ?? .identity) != .identity {
                    ResetButton(action: { state.resetTransform(at: focused) })
                        .padding(10)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(Brand.Animations.fadeFast, value: state.renderedPreview)
            .animation(.easeInOut(duration: 0.12), value: state.isInteracting)
            .animation(Brand.Animations.fadeFast, value: state.focusedIndex)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
    }
}

private struct FocusRing: View {
    let state: CollageState
    let focusedIndex: Int
    let canvasSize: CGSize

    var body: some View {
        let refSize = CollageRenderer.canvasSize
        let scaleX = canvasSize.width / refSize.width
        let scaleY = canvasSize.height / refSize.height
        let frames = CollageGeometry.frames(for: state.preset, count: state.photos.count, in: refSize)
        if focusedIndex < frames.count {
            let f = frames[focusedIndex]
            let cell = CGRect(
                x: f.origin.x * scaleX,
                y: f.origin.y * scaleY,
                width: f.width * scaleX,
                height: f.height * scaleY
            )
            RoundedRectangle(cornerRadius: state.effectiveStyle.cornerRadius, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: cell.width, height: cell.height)
                .position(x: cell.midX, y: cell.midY)
                .allowsHitTesting(false)
        }
    }
}

private struct ResetButton: View {
    let action: () -> Void
    var body: some View {
        Button {
            HapticsManager.playImpact(style: .light)
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                Text(String(localized: "merkeze al"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Per-photo interactive overlay for pan + zoom. Sits above the rendered
/// preview and routes gestures to the corresponding CollageState transform.
private struct CollageInteractiveLayer: View {
    @Bindable var state: CollageState
    let canvasSize: CGSize

    var body: some View {
        let refSize = CollageRenderer.canvasSize
        let scaleX = canvasSize.width / refSize.width
        let scaleY = canvasSize.height / refSize.height
        let frames = CollageGeometry.frames(for: state.preset, count: state.photos.count, in: refSize)

        ZStack {
            ForEach(0..<min(frames.count, state.photos.count), id: \.self) { (i: Int) in
                let f = frames[i]
                let scaled = CGRect(
                    x: f.origin.x * scaleX,
                    y: f.origin.y * scaleY,
                    width: f.width * scaleX,
                    height: f.height * scaleY
                )
                CollageGestureHotspot(state: state, index: i, cell: scaled)
                    .id("\(state.preset.rawValue)-\(i)")
            }
        }
    }
}

/// Invisible touch target. Live-writes pan/zoom to state on every gesture
/// tick so the SwiftUI live preview moves under the finger.
private struct CollageGestureHotspot: View {
    let state: CollageState
    let index: Int
    let cell: CGRect

    @State private var dragStart: CGSize?      // transform.offset at drag start
    @State private var pinchStart: CGFloat?    // transform.scale at pinch start

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: cell.width, height: cell.height)
            .position(x: cell.midX, y: cell.midY)
            .gesture(
                SimultaneousGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            applyDrag(translation: value.translation)
                        }
                        .onEnded { _ in
                            dragStart = nil
                            state.endInteraction()
                            HapticsManager.playImpact(style: .light)
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            applyPinch(scale: value)
                        }
                        .onEnded { _ in
                            pinchStart = nil
                            state.endInteraction()
                            HapticsManager.playImpact(style: .light)
                        }
                )
            )
    }

    private func applyDrag(translation: CGSize) {
        let current = state.transforms[index] ?? .identity
        if dragStart == nil {
            dragStart = current.offset
            state.beginInteraction(at: index)
        }
        // Translate finger delta to normalized -1...1 against the actual
        // overflow at the current scale.
        let approxOverflowX = max(1, cell.width * 0.5 * max(0.05, current.scale - 1))
        let approxOverflowY = max(1, cell.height * 0.5 * max(0.05, current.scale - 1))
        let dxN = translation.width / approxOverflowX
        let dyN = translation.height / approxOverflowY
        let baseX = dragStart?.width ?? 0
        let baseY = dragStart?.height ?? 0
        let nx = max(-1, min(1, baseX + dxN))
        let ny = max(-1, min(1, baseY + dyN))
        var t = current
        t.offset = CGSize(width: nx, height: ny)
        state.setTransform(t, at: index)
    }

    private func applyPinch(scale: CGFloat) {
        let current = state.transforms[index] ?? .identity
        if pinchStart == nil {
            pinchStart = current.scale
            state.beginInteraction(at: index)
        }
        let base = pinchStart ?? 1.0
        let newScale = max(1.0, min(3.0, base * scale))
        var t = current
        t.scale = newScale
        // When zooming back to 1.0, snap pan to center so a slight drift
        // doesn't keep an invisible offset that bites later.
        if newScale <= 1.001 {
            t.offset = .zero
        }
        state.setTransform(t, at: index)
    }
}
