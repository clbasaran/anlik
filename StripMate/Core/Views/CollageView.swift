import SwiftUI

// MARK: - Collage View

/// Displays 2-4 captured photos in a selectable grid layout with interactive
/// per-photo pan/zoom editing, layout templates, gap, corner, background and aspect ratio controls.
public struct CollageView: View {
    let photos: [UIImage]
    var onFinalize: (UIImage) -> Void
    var onCancel: () -> Void
    var onAddMore: () -> Void
    var onRemovePhoto: (Int) -> Void
    var onReplacePhoto: (Int) -> Void

    @State private var selectedLayout: CollageLayout
    @State private var gapSize: CGFloat = 4
    @State private var cornerStyle: CollageCornerStyle = .rounded
    @State private var selectedBackground: CollageBackground = .black
    @State private var selectedAspectRatio: CollageAspectRatio = .portrait
    @State private var photoOrder: [Int]
    @State private var renderedCollage: UIImage?
    @State private var isRendering: Bool = false
    @State private var renderTask: Task<Void, Never>?
    @State private var appeared = false
    @State private var showFinalizeTick = false

    // Per-photo transforms (pan + zoom)
    @State private var photoTransforms: [Int: PhotoTransform] = [:]
    @State private var activeCell: Int? = nil

    public init(
        photos: [UIImage],
        onFinalize: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void,
        onAddMore: @escaping () -> Void,
        onRemovePhoto: @escaping (Int) -> Void = { _ in },
        onReplacePhoto: @escaping (Int) -> Void = { _ in }
    ) {
        self.photos = photos
        self.onFinalize = onFinalize
        self.onCancel = onCancel
        self.onAddMore = onAddMore
        self.onRemovePhoto = onRemovePhoto
        self.onReplacePhoto = onReplacePhoto

        let defaultLayout: CollageLayout
        switch photos.count {
        case 2: defaultLayout = .twoHorizontal
        case 3: defaultLayout = .threeLeftLarge
        case 4: defaultLayout = .fourGrid
        default: defaultLayout = .twoHorizontal
        }
        _selectedLayout = State(initialValue: defaultLayout)
        _photoOrder = State(initialValue: Array(0..<photos.count))
    }

    private var availableLayouts: [CollageLayout] {
        CollageLayout.layouts(for: photos.count)
    }

    private var canAddMore: Bool {
        photos.count < 4
    }

    private var orderedPhotos: [UIImage] {
        photoOrder.compactMap { idx in
            idx < photos.count ? photos[idx] : nil
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                photoStrip
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                // Interactive collage preview
                interactivePreview
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    aspectRatioPicker
                    layoutSelector
                    controlsSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }

            // Finalize tick overlay
            if showFinalizeTick {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: showFinalizeTick)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            syncPhotoOrder()
            scheduleRender()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            renderTask?.cancel()
        }
        .onChange(of: photos.count) { _, _ in
            syncPhotoOrder()
            if selectedLayout.photoCount != photos.count {
                selectedLayout = availableLayouts.first ?? .twoHorizontal
            }
            scheduleRender()
        }
        .onChange(of: selectedLayout) { _, _ in
            HapticsManager.playSelection()
            // Reset transforms on layout change
            photoTransforms = [:]
            scheduleRender()
        }
        .onChange(of: gapSize) { _, _ in
            scheduleRender()
        }
        .onChange(of: selectedBackground) { _, _ in
            HapticsManager.playSelection()
            scheduleRender()
        }
        .onChange(of: cornerStyle) { _, _ in
            HapticsManager.playSelection()
            scheduleRender()
        }
        .onChange(of: selectedAspectRatio) { _, _ in
            HapticsManager.playSelection()
            photoTransforms = [:]
            scheduleRender()
        }
    }

    // MARK: - Sync Photo Order

    private func syncPhotoOrder() {
        if photoOrder.count != photos.count {
            photoOrder = Array(0..<photos.count)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                HapticsManager.playSelection()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            VStack(spacing: 2) {
                Text(String(localized: "kolaj"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                if activeCell != nil {
                    Text(String(localized: "fotoğrafı sürükle"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .transition(.opacity)
                }
            }

            Spacer()

            Text("\(photos.count)/4")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 44, height: 44)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(photoOrder.enumerated()), id: \.offset) { offset, photoIndex in
                if photoIndex < photos.count {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: photos[photoIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        // Number badge
                        Text("\(offset + 1)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .offset(x: -4, y: -4)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            HapticsManager.playImpact(style: .light)
                            onRemovePhoto(photoIndex)
                        } label: {
                            Label(String(localized: "kaldır"), systemImage: "trash")
                        }

                        Button {
                            HapticsManager.playImpact(style: .medium)
                            onReplacePhoto(photoIndex)
                        } label: {
                            Label(String(localized: "yeniden çek"), systemImage: "camera")
                        }

                        if photoTransforms[offset] != nil {
                            Button {
                                photoTransforms[offset] = nil
                                scheduleRender()
                            } label: {
                                Label(String(localized: "konumu sıfırla"), systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                    .onTapGesture {
                        let nextOffset = (offset + 1) % photoOrder.count
                        if nextOffset != offset {
                            HapticsManager.playSelection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                photoOrder.swapAt(offset, nextOffset)
                                // Also swap transforms
                                let t1 = photoTransforms[offset]
                                let t2 = photoTransforms[nextOffset]
                                photoTransforms[offset] = t2
                                photoTransforms[nextOffset] = t1
                            }
                            scheduleRender()
                        }
                    }
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7).delay(Double(offset) * 0.08),
                        value: appeared
                    )
                }
            }
        }
    }

    // MARK: - Interactive Preview

    private var interactivePreview: some View {
        GeometryReader { geo in
            let previewSize = geo.size
            let refSize = CGSize(width: selectedAspectRatio.width, height: selectedAspectRatio.height)
            let scaleX = previewSize.width / refSize.width
            let scaleY = previewSize.height / refSize.height
            let frames = CollageBuilder.cellFrames(for: selectedLayout, in: refSize, gap: gapSize)
            let radius: CGFloat = cornerStyle == .rounded ? 24 * min(scaleX, scaleY) : 0

            ZStack {
                // Background
                backgroundLayer(size: previewSize)

                // Each photo cell is an independent interactive view
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    if index < orderedPhotos.count {
                        let scaledFrame = CGRect(
                            x: frame.origin.x * scaleX,
                            y: frame.origin.y * scaleY,
                            width: frame.width * scaleX,
                            height: frame.height * scaleY
                        )

                        InteractivePhotoCell(
                            image: orderedPhotos[index],
                            frame: scaledFrame,
                            cornerRadius: radius,
                            transform: Binding(
                                get: { photoTransforms[index] ?? .identity },
                                set: { newValue in
                                    photoTransforms[index] = newValue
                                    scheduleRender()
                                }
                            ),
                            isActive: Binding(
                                get: { activeCell == index },
                                set: { isActive in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        activeCell = isActive ? index : nil
                                    }
                                }
                            )
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .white.opacity(0.04), radius: 20, y: 4)
        }
        .aspectRatio(selectedAspectRatio.ratio, contentMode: .fit)
    }

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        switch selectedBackground {
        case .black:
            Color.black
        case .white:
            Color.white
        case .blurFill:
            if let first = orderedPhotos.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .blur(radius: 30)
            } else {
                Color.black
            }
        }
    }

    // MARK: - Aspect Ratio Picker

    private var aspectRatioPicker: some View {
        HStack(spacing: 0) {
            ForEach(CollageAspectRatio.allCases, id: \.rawValue) { ratio in
                let isSelected = ratio == selectedAspectRatio
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedAspectRatio = ratio
                    }
                } label: {
                    Text(ratio.label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Layout Selector

    private var layoutSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableLayouts) { layout in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedLayout = layout
                        }
                    } label: {
                        liveLayoutPreview(for: layout)
                            .frame(width: 36, height: layoutThumbnailHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        selectedLayout == layout
                                            ? Color.white.opacity(0.8)
                                            : Color.white.opacity(0.1),
                                        lineWidth: selectedLayout == layout ? 2 : 1
                                    )
                            )
                            .scaleEffect(selectedLayout == layout ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLayout == layout)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var layoutThumbnailHeight: CGFloat {
        switch selectedAspectRatio {
        case .portrait: return 64
        case .instagram: return 45
        case .square: return 36
        }
    }

    @ViewBuilder
    private func liveLayoutPreview(for layout: CollageLayout) -> some View {
        Canvas { context, canvasSize in
            let refSize = CGSize(width: selectedAspectRatio.width, height: selectedAspectRatio.height)
            let frames = CollageBuilder.cellFrames(for: layout, in: refSize, gap: refSize.width * 0.01)
            let currentPhotos = orderedPhotos

            let scaleX = canvasSize.width / refSize.width
            let scaleY = canvasSize.height / refSize.height

            for (index, frame) in frames.enumerated() {
                let scaledFrame = CGRect(
                    x: frame.origin.x * scaleX,
                    y: frame.origin.y * scaleY,
                    width: frame.width * scaleX,
                    height: frame.height * scaleY
                )
                if index < currentPhotos.count {
                    let img = currentPhotos[index]
                    let resolved = context.resolve(Image(uiImage: img))
                    context.clip(to: Path(roundedRect: scaledFrame, cornerRadius: 2))
                    let imgSize = img.size
                    let imgRatio = imgSize.width / imgSize.height
                    let cellRatio = scaledFrame.width / scaledFrame.height
                    var drawRect: CGRect
                    if imgRatio > cellRatio {
                        let drawH = scaledFrame.height
                        let drawW = drawH * imgRatio
                        drawRect = CGRect(x: scaledFrame.midX - drawW / 2, y: scaledFrame.minY, width: drawW, height: drawH)
                    } else {
                        let drawW = scaledFrame.width
                        let drawH = drawW / imgRatio
                        drawRect = CGRect(x: scaledFrame.minX, y: scaledFrame.midY - drawH / 2, width: drawW, height: drawH)
                    }
                    context.draw(resolved, in: drawRect)
                    context.clip(to: Path(CGRect(origin: .zero, size: canvasSize)))
                } else {
                    context.fill(Path(roundedRect: scaledFrame, cornerRadius: 2), with: .color(.white.opacity(0.1)))
                }
            }
        }
        .background(Color.black)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))

                Slider(value: $gapSize, in: 0...20, step: 1)
                    .tint(.white)

                Text("\(Int(gapSize))px")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text(String(localized: "köşe"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cornerStyle = (cornerStyle == .sharp) ? .rounded : .sharp
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cornerStyle == .sharp ? "square" : "square.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(cornerStyle == .sharp ? String(localized: "keskin") : String(localized: "yumuşak"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(String(localized: "arka plan"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    backgroundCircle(fill: AnyShapeStyle(Color.black), isSelected: selectedBackground == .black, borderColor: .white) { selectedBackground = .black }
                    backgroundCircle(fill: AnyShapeStyle(Color.white), isSelected: selectedBackground == .white, borderColor: .white) { selectedBackground = .white }
                    backgroundCircle(
                        fill: AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                        isSelected: selectedBackground == .blurFill,
                        borderColor: .white
                    ) { selectedBackground = .blurFill }
                }
            }
        }
    }

    @ViewBuilder
    private func backgroundCircle(fill: AnyShapeStyle, isSelected: Bool, borderColor: Color, action: @escaping () -> Void) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(isSelected ? borderColor : borderColor.opacity(0.2), lineWidth: isSelected ? 2 : 1))
            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .onTapGesture { action() }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            if canAddMore {
                Button {
                    HapticsManager.playImpact(style: .light)
                    onAddMore()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text(String(localized: "foto ekle"))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Spacer()

            Button {
                guard renderedCollage != nil else { return }
                HapticsManager.playNotification(type: .success)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showFinalizeTick = true
                }
                // Render final with transforms
                let currentPhotos = orderedPhotos
                let layout = selectedLayout
                let gap = gapSize
                let bg = selectedBackground
                let corner = cornerStyle
                let ratio = selectedAspectRatio
                let transforms = photoTransforms

                Task.detached(priority: .userInitiated) {
                    guard let finalImage = CollageBuilder.build(
                        images: currentPhotos,
                        layout: layout,
                        gap: gap,
                        background: bg,
                        cornerStyle: corner,
                        aspectRatio: ratio,
                        transforms: transforms
                    ) else { return }
                    await MainActor.run {
                        onFinalize(finalImage)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(String(localized: "kullan"))
                        .font(.system(.title3, weight: .heavy))
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundColor(.black)
                .padding(.vertical, 18)
                .padding(.horizontal, 32)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(renderedCollage == nil)
            .opacity(renderedCollage == nil ? 0.4 : 1)
        }
    }

    // MARK: - Background Render (for finalize check)

    private func scheduleRender() {
        renderTask?.cancel()
        isRendering = true

        let currentPhotos = orderedPhotos
        let layout = selectedLayout
        let gap = gapSize
        let bg = selectedBackground
        let corner = cornerStyle
        let ratio = selectedAspectRatio
        let transforms = photoTransforms

        renderTask = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return }
            let img = CollageBuilder.build(
                images: currentPhotos,
                layout: layout,
                gap: gap,
                background: bg,
                cornerStyle: corner,
                aspectRatio: ratio,
                transforms: transforms
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                renderedCollage = img
                isRendering = false
            }
        }
    }
}

// MARK: - Interactive Photo Cell

/// A single photo cell within the collage that supports drag-to-pan and pinch-to-zoom.
private struct InteractivePhotoCell: View {
    let image: UIImage
    let frame: CGRect
    let cornerRadius: CGFloat
    @Binding var transform: PhotoTransform
    @Binding var isActive: Bool

    // Gesture accumulators
    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0

    var body: some View {
        let imgSize = image.size
        let imgRatio = imgSize.width / imgSize.height
        let cellRatio = frame.width / frame.height

        // Base aspect-fill size
        let baseW: CGFloat = imgRatio > cellRatio ? frame.height * imgRatio : frame.width
        let baseH: CGFloat = imgRatio > cellRatio ? frame.height : frame.width / imgRatio

        // Current total scale
        let totalScale = transform.scale * pinchScale

        // Current image draw size
        let drawW = baseW * totalScale
        let drawH = baseH * totalScale

        // Max pan range (how far the image overflows the cell)
        let overflowX = max(0, (drawW - frame.width) / 2)
        let overflowY = max(0, (drawH - frame.height) / 2)

        // Current offset in points
        let currentOffsetX = transform.offset.width * overflowX + dragOffset.width
        let currentOffsetY = transform.offset.height * overflowY + dragOffset.height

        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: drawW, height: drawH)
            .offset(x: currentOffsetX, y: currentOffsetY)
            .frame(width: frame.width, height: frame.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .position(x: frame.midX, y: frame.midY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isActive = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // Commit drag to normalized offset
                        let newOverflowX = max(1, (drawW - frame.width) / 2)
                        let newOverflowY = max(1, (drawH - frame.height) / 2)
                        var newOffX = transform.offset.width + value.translation.width / newOverflowX
                        var newOffY = transform.offset.height + value.translation.height / newOverflowY
                        newOffX = max(-1, min(1, newOffX))
                        newOffY = max(-1, min(1, newOffY))
                        transform.offset = CGSize(width: newOffX, height: newOffY)
                        dragOffset = .zero
                        isActive = false
                        HapticsManager.playImpact(style: .light)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        isActive = true
                        pinchScale = value
                    }
                    .onEnded { value in
                        let newScale = max(1.0, min(3.0, transform.scale * value))
                        transform.scale = newScale
                        pinchScale = 1.0
                        isActive = false
                        HapticsManager.playImpact(style: .light)
                    }
            )
    }
}

// MARK: - Corner Style

public enum CollageCornerStyle: String, CaseIterable {
    case sharp
    case rounded
}
