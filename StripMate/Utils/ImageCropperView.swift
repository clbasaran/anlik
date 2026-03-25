import SwiftUI

/// Circular image cropper — lets the user pan and zoom to frame their profile photo.
///
/// Key design:
/// - At scale 1.0 the image fills the crop circle via aspect-fill.
/// - The full image extent is rendered (not clipped to a square) so the user can
///   pan freely across the longer dimension.
/// - Offset is clamped so the crop circle is always covered.
struct ImageCropperView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // Gesture state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    // MARK: - Derived sizes

    /// Display size when the image exactly aspect-fills the crop circle (scale == 1).
    private var baseDisplaySize: CGSize {
        let imgW = image.size.width
        let imgH = image.size.height
        guard imgW > 0, imgH > 0 else {
            return CGSize(width: cropDiameter, height: cropDiameter)
        }

        let ratio = imgW / imgH
        if ratio > 1 {
            // Landscape: height matches crop diameter, width extends
            return CGSize(width: cropDiameter * ratio, height: cropDiameter)
        } else {
            // Portrait / square: width matches crop diameter, height extends
            return CGSize(width: cropDiameter, height: cropDiameter / ratio)
        }
    }

    /// Current display size taking zoom into account.
    private var displaySize: CGSize {
        CGSize(
            width: baseDisplaySize.width * scale,
            height: baseDisplaySize.height * scale
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "iptal"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Text(String(localized: "fotoğrafı ayarla"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        let cropped = cropImage()
                        onCropped(cropped)
                        dismiss()
                    } label: {
                        Text(String(localized: "tamam"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Spacer()

                // Crop area — clipped so image doesn't overflow into header/footer
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                    ZStack {
                        // Image layer — full aspect-fill size, NOT clipped to a square
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: displaySize.width, height: displaySize.height)
                            .offset(offset)
                            .position(center)

                        // Dark overlay with circular cutout
                        Canvas { context, size in
                            let rect = CGRect(origin: .zero, size: size)
                            let circleRect = CGRect(
                                x: center.x - cropDiameter / 2,
                                y: center.y - cropDiameter / 2,
                                width: cropDiameter,
                                height: cropDiameter
                            )

                            context.fill(Path(rect), with: .color(.black.opacity(0.6)))
                            context.blendMode = .destinationOut
                            context.fill(Path(ellipseIn: circleRect), with: .color(.white))
                        }
                        .allowsHitTesting(false)

                        // Circle border
                        Circle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                            .frame(width: cropDiameter, height: cropDiameter)
                            .position(center)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                                clampOffset(animated: false)
                            }
                            .onEnded { _ in
                                if scale < minScale {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = minScale
                                    }
                                }
                                lastScale = scale
                                clampOffset()
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                clampOffset()
                                lastOffset = offset
                            }
                    )
                }
                .clipped()

                Spacer()

                // Confirm button — large and prominent
                Button {
                    let cropped = cropImage()
                    onCropped(cropped)
                    dismiss()
                } label: {
                    Text(String(localized: "onayla"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                // Hint text
                Text(String(localized: "fotoğrafı sürükle ve yakınlaştır"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Helpers

    /// Keep offset within bounds so the image always covers the crop circle.
    private func clampOffset(animated: Bool = true) {
        let maxX = max(0, (displaySize.width - cropDiameter) / 2)
        let maxY = max(0, (displaySize.height - cropDiameter) / 2)

        let clampedW = min(max(offset.width, -maxX), maxX)
        let clampedH = min(max(offset.height, -maxY), maxY)

        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = CGSize(width: clampedW, height: clampedH)
            }
        } else {
            offset = CGSize(width: clampedW, height: clampedH)
        }
    }

    /// Crop the image based on current scale and offset.
    private func cropImage() -> UIImage {
        let normalizedImage = image.normalizedOrientation()
        let imgSize = normalizedImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return normalizedImage }

        // The ratio from display points → image pixels (at current zoom)
        let pixelsPerPointX = imgSize.width / displaySize.width
        let pixelsPerPointY = imgSize.height / displaySize.height

        // Center of the crop circle in image pixel coordinates
        let centerX = imgSize.width / 2 - offset.width * pixelsPerPointX
        let centerY = imgSize.height / 2 - offset.height * pixelsPerPointY

        // Radius of the crop circle in image pixel coordinates
        let cropRadiusX = (cropDiameter / 2) * pixelsPerPointX
        let cropRadiusY = (cropDiameter / 2) * pixelsPerPointY

        // Because the image is aspect-filled, pixelsPerPointX ≈ pixelsPerPointY,
        // but use the average for a clean square crop rect
        let cropRadius = (cropRadiusX + cropRadiusY) / 2

        let cropRect = CGRect(
            x: centerX - cropRadius,
            y: centerY - cropRadius,
            width: cropRadius * 2,
            height: cropRadius * 2
        ).intersection(CGRect(origin: .zero, size: imgSize))

        guard let cgImage = normalizedImage.cgImage?.cropping(to: cropRect) else {
            return normalizedImage
        }

        // Render as circular 512×512
        let outputSize: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: CGSize(width: outputSize, height: outputSize))
            UIBezierPath(ovalIn: rect).addClip()
            UIImage(cgImage: cgImage).draw(in: rect)
        }
    }
}
