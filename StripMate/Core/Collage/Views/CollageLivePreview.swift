import SwiftUI

/// Cheap SwiftUI mirror of the bitmap renderer used during active gestures.
/// The bitmap renderer is precise but takes ~50–150ms per compose; running
/// it on every drag tick produces visible flicker. This view draws the same
/// layout entirely in SwiftUI (no CoreImage, no offscreen bitmap), so pan
/// and zoom track the finger 1:1. As soon as the gesture ends the screen
/// flips back to the rendered bitmap.
struct CollageLivePreview: View {
    @Bindable var state: CollageState

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let refSize = CollageRenderer.canvasSize
            let scaleX = canvas.width / refSize.width
            let scaleY = canvas.height / refSize.height
            let frames = CollageGeometry.frames(for: state.preset, count: state.photos.count, in: refSize)
            let style = state.effectiveStyle

            ZStack {
                background(style: style, canvas: canvas)

                ForEach(0..<min(frames.count, state.photos.count), id: \.self) { (i: Int) in
                    let f = frames[i]
                    let cell = CGRect(
                        x: f.origin.x * scaleX,
                        y: f.origin.y * scaleY,
                        width: f.width * scaleX,
                        height: f.height * scaleY
                    )
                    cellView(index: i, cell: cell, style: style)
                }

                if style.divider != nil {
                    dividers(frames: frames, scaleX: scaleX, scaleY: scaleY, divider: style.divider!)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
    }

    @ViewBuilder
    private func background(style: CollagePreset.Style, canvas: CGSize) -> some View {
        switch style.background {
        case .solid(let color):
            Rectangle()
                .fill(color == .white ? Color.white : Color.black)
        case .blurOfFirst:
            // Approximate the renderer's gaussian blur with SwiftUI's cheap
            // .blur — perceptually identical at preview scale.
            if let first = state.photos.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvas.width, height: canvas.height)
                    .blur(radius: 22)
                    .clipped()
            } else {
                Rectangle().fill(Color.black)
            }
        }
    }

    @ViewBuilder
    private func cellView(index: Int, cell: CGRect, style: CollagePreset.Style) -> some View {
        let img = state.photos[index]
        let transform = state.transforms[index] ?? .identity

        // Aspect-fill base size in cell, then apply scale + normalized pan.
        let base = aspectFillSize(image: img.size, in: cell.size)
        let scaledW = base.width * transform.scale
        let scaledH = base.height * transform.scale
        let overflowX = max(0, (scaledW - cell.width) / 2)
        let overflowY = max(0, (scaledH - cell.height) / 2)
        let panX = transform.offset.width * overflowX
        let panY = transform.offset.height * overflowY

        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: scaledW, height: scaledH)
            .offset(x: panX, y: panY)
            .frame(width: cell.width, height: cell.height)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .position(x: cell.midX, y: cell.midY)
    }

    @ViewBuilder
    private func dividers(frames: [CGRect], scaleX: CGFloat, scaleY: CGFloat, divider: CollagePreset.Style.Divider) -> some View {
        let color: Color = divider.color == .white ? .white : .black
        ForEach(1..<frames.count, id: \.self) { (i: Int) in
            let prev = frames[i - 1]
            let curr = frames[i]
            let y = (prev.maxY + curr.minY) / 2 * scaleY
            Rectangle()
                .fill(color)
                .frame(width: prev.width * scaleX, height: divider.thickness)
                .position(x: prev.midX * scaleX, y: y)
        }
    }

    private func aspectFillSize(image: CGSize, in bounds: CGSize) -> CGSize {
        let imageRatio = image.width / image.height
        let boundsRatio = bounds.width / bounds.height
        if imageRatio > boundsRatio {
            let h = bounds.height
            return CGSize(width: h * imageRatio, height: h)
        } else {
            let w = bounds.width
            return CGSize(width: w, height: w / imageRatio)
        }
    }
}
