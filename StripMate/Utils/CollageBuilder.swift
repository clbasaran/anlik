import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Collage Aspect Ratio

public enum CollageAspectRatio: String, CaseIterable {
    case portrait   // 9:16
    case instagram  // 4:5
    case square     // 1:1

    public var label: String {
        switch self {
        case .portrait: return "9:16"
        case .instagram: return "4:5"
        case .square: return "1:1"
        }
    }

    public var width: CGFloat { 1080 }

    public var height: CGFloat {
        switch self {
        case .portrait: return 1920
        case .instagram: return 1350
        case .square: return 1080
        }
    }

    public var ratio: CGFloat { width / height }
}

// MARK: - Collage Layout

/// Layout options for combining 2-4 photos into a single collage strip.
public enum CollageLayout: CaseIterable, Identifiable {
    // 2-photo layouts
    case twoHorizontal        // side by side
    case twoVertical          // top/bottom
    case twoDiagonal          // diagonal split — left-top big, right-bottom big
    case twoLeftWide          // 70/30 left dominant

    // 3-photo layouts
    case threeLeftLarge       // 1 big left + 2 small stacked right
    case threeTopLarge        // 1 big top + 2 small side-by-side bottom
    case threeRightLarge      // 2 small stacked left + 1 big right
    case threeBottomLarge     // 2 small top + 1 big bottom
    case threeEqualRows       // 3 horizontal rows equal
    case threeEqualCols       // 3 vertical columns equal

    // 4-photo layouts
    case fourGrid             // 2x2 grid
    case fourTopRow           // 1 big top + 3 small bottom
    case fourBottomRow        // 3 small top + 1 big bottom
    case fourLeftCol          // 1 big left + 3 stacked right
    case fourCenterFocus      // big center overlap style: top-left, top-right, bottom-left, bottom-right with center emphasis

    public var id: String {
        switch self {
        case .twoHorizontal: return "twoH"
        case .twoVertical: return "twoV"
        case .twoDiagonal: return "twoDiag"
        case .twoLeftWide: return "twoLW"
        case .threeLeftLarge: return "threeL"
        case .threeTopLarge: return "threeT"
        case .threeRightLarge: return "threeR"
        case .threeBottomLarge: return "threeB"
        case .threeEqualRows: return "threeER"
        case .threeEqualCols: return "threeEC"
        case .fourGrid: return "fourG"
        case .fourTopRow: return "fourTR"
        case .fourBottomRow: return "fourBR"
        case .fourLeftCol: return "fourLC"
        case .fourCenterFocus: return "fourCF"
        }
    }

    public var photoCount: Int {
        switch self {
        case .twoHorizontal, .twoVertical, .twoDiagonal, .twoLeftWide: return 2
        case .threeLeftLarge, .threeTopLarge, .threeRightLarge, .threeBottomLarge,
             .threeEqualRows, .threeEqualCols: return 3
        case .fourGrid, .fourTopRow, .fourBottomRow, .fourLeftCol, .fourCenterFocus: return 4
        }
    }

    /// Layouts available for a given photo count.
    public static func layouts(for count: Int) -> [CollageLayout] {
        allCases.filter { $0.photoCount == count }
    }
}

// MARK: - Photo Transform

/// Per-photo pan/zoom state for interactive collage editing.
/// offset is normalized (0-1 range relative to overflow), scale >= 1.0.
public struct PhotoTransform: Equatable {
    public var offset: CGSize = .zero   // normalized pan offset (-1...1)
    public var scale: CGFloat = 1.0     // pinch-to-zoom (1.0 = aspect fill)

    public static let identity = PhotoTransform()
}

// MARK: - Collage Background

public enum CollageBackground: String, CaseIterable {
    case black
    case white
    case blurFill
}

// MARK: - Collage Builder

/// Renders an array of UIImages into a single portrait collage image.
public enum CollageBuilder {

    /// Builds a collage from the given images using the specified layout.
    /// `transforms` allows per-photo pan/zoom adjustments from the interactive editor.
    public static func build(
        images: [UIImage],
        layout: CollageLayout,
        gap: CGFloat = 4,
        background: CollageBackground = .black,
        cornerStyle: CollageCornerStyle = .rounded,
        aspectRatio: CollageAspectRatio = .portrait,
        transforms: [Int: PhotoTransform] = [:]
    ) -> UIImage? {
        guard images.count >= layout.photoCount else { return nil }

        let normalized = images.map { $0.normalizedOrientation().resizedToMax(dimension: 1440) }

        let size = CGSize(width: aspectRatio.width, height: aspectRatio.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let radius: CGFloat = cornerStyle == .rounded ? 24 : 0

        return autoreleasepool {
            renderer.image { context in
                // Background
                switch background {
                case .black:
                    UIColor.black.setFill()
                    context.fill(CGRect(origin: .zero, size: size))

                case .white:
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))

                case .blurFill:
                    drawBlurredBackground(
                        from: normalized.first,
                        in: CGRect(origin: .zero, size: size),
                        context: context.cgContext
                    )
                }

                let frames = cellFrames(for: layout, in: size, gap: gap)

                for (index, frame) in frames.enumerated() where index < normalized.count {
                    let img = normalized[index]
                    let transform = transforms[index] ?? .identity
                    drawImage(img, in: frame, cornerRadius: radius, transform: transform, context: context.cgContext)
                }
            }
        }
    }

    // MARK: - Frame Calculation

    public static func cellFrames(for layout: CollageLayout, in size: CGSize, gap: CGFloat = 4) -> [CGRect] {
        let w = size.width
        let h = size.height
        let g = gap

        switch layout {
        // ── 2-photo ────────────────────────────────────
        case .twoHorizontal:
            let cellW = (w - g) / 2
            return [
                CGRect(x: 0, y: 0, width: cellW, height: h),
                CGRect(x: cellW + g, y: 0, width: cellW, height: h)
            ]

        case .twoVertical:
            let cellH = (h - g) / 2
            return [
                CGRect(x: 0, y: 0, width: w, height: cellH),
                CGRect(x: 0, y: cellH + g, width: w, height: cellH)
            ]

        case .twoDiagonal:
            // Top-left large (60%) + bottom-right large (60%) with overlap gap
            let splitX = w * 0.55
            let splitY = h * 0.55
            return [
                CGRect(x: 0, y: 0, width: splitX - g / 2, height: splitY - g / 2),
                CGRect(x: splitX + g / 2, y: splitY + g / 2, width: w - splitX - g / 2, height: h - splitY - g / 2)
            ]

        case .twoLeftWide:
            // 70/30 left dominant
            let leftW = (w - g) * 0.7
            return [
                CGRect(x: 0, y: 0, width: leftW, height: h),
                CGRect(x: leftW + g, y: 0, width: w - leftW - g, height: h)
            ]

        // ── 3-photo ────────────────────────────────────
        case .threeLeftLarge:
            let leftW = (w - g) * 0.6
            let rightW = w - leftW - g
            let rightH = (h - g) / 2
            return [
                CGRect(x: 0, y: 0, width: leftW, height: h),
                CGRect(x: leftW + g, y: 0, width: rightW, height: rightH),
                CGRect(x: leftW + g, y: rightH + g, width: rightW, height: rightH)
            ]

        case .threeTopLarge:
            let topH = (h - g) * 0.6
            let bottomH = h - topH - g
            let cellW = (w - g) / 2
            return [
                CGRect(x: 0, y: 0, width: w, height: topH),
                CGRect(x: 0, y: topH + g, width: cellW, height: bottomH),
                CGRect(x: cellW + g, y: topH + g, width: cellW, height: bottomH)
            ]

        case .threeRightLarge:
            let rightW = (w - g) * 0.6
            let leftW = w - rightW - g
            let leftH = (h - g) / 2
            return [
                CGRect(x: 0, y: 0, width: leftW, height: leftH),
                CGRect(x: 0, y: leftH + g, width: leftW, height: leftH),
                CGRect(x: leftW + g, y: 0, width: rightW, height: h)
            ]

        case .threeBottomLarge:
            let bottomH = (h - g) * 0.6
            let topH = h - bottomH - g
            let cellW = (w - g) / 2
            return [
                CGRect(x: 0, y: 0, width: cellW, height: topH),
                CGRect(x: cellW + g, y: 0, width: cellW, height: topH),
                CGRect(x: 0, y: topH + g, width: w, height: bottomH)
            ]

        case .threeEqualRows:
            let cellH = (h - 2 * g) / 3
            return [
                CGRect(x: 0, y: 0, width: w, height: cellH),
                CGRect(x: 0, y: cellH + g, width: w, height: cellH),
                CGRect(x: 0, y: 2 * (cellH + g), width: w, height: cellH)
            ]

        case .threeEqualCols:
            let cellW = (w - 2 * g) / 3
            return [
                CGRect(x: 0, y: 0, width: cellW, height: h),
                CGRect(x: cellW + g, y: 0, width: cellW, height: h),
                CGRect(x: 2 * (cellW + g), y: 0, width: cellW, height: h)
            ]

        // ── 4-photo ────────────────────────────────────
        case .fourGrid:
            let cellW = (w - g) / 2
            let cellH = (h - g) / 2
            return [
                CGRect(x: 0, y: 0, width: cellW, height: cellH),
                CGRect(x: cellW + g, y: 0, width: cellW, height: cellH),
                CGRect(x: 0, y: cellH + g, width: cellW, height: cellH),
                CGRect(x: cellW + g, y: cellH + g, width: cellW, height: cellH)
            ]

        case .fourTopRow:
            // 1 big top (60%) + 3 small bottom
            let topH = (h - g) * 0.6
            let bottomH = h - topH - g
            let cellW = (w - 2 * g) / 3
            return [
                CGRect(x: 0, y: 0, width: w, height: topH),
                CGRect(x: 0, y: topH + g, width: cellW, height: bottomH),
                CGRect(x: cellW + g, y: topH + g, width: cellW, height: bottomH),
                CGRect(x: 2 * (cellW + g), y: topH + g, width: cellW, height: bottomH)
            ]

        case .fourBottomRow:
            // 3 small top + 1 big bottom (60%)
            let bottomH = (h - g) * 0.6
            let topH = h - bottomH - g
            let cellW = (w - 2 * g) / 3
            return [
                CGRect(x: 0, y: 0, width: cellW, height: topH),
                CGRect(x: cellW + g, y: 0, width: cellW, height: topH),
                CGRect(x: 2 * (cellW + g), y: 0, width: cellW, height: topH),
                CGRect(x: 0, y: topH + g, width: w, height: bottomH)
            ]

        case .fourLeftCol:
            // 1 big left (60%) + 3 stacked right
            let leftW = (w - g) * 0.6
            let rightW = w - leftW - g
            let cellH = (h - 2 * g) / 3
            return [
                CGRect(x: 0, y: 0, width: leftW, height: h),
                CGRect(x: leftW + g, y: 0, width: rightW, height: cellH),
                CGRect(x: leftW + g, y: cellH + g, width: rightW, height: cellH),
                CGRect(x: leftW + g, y: 2 * (cellH + g), width: rightW, height: cellH)
            ]

        case .fourCenterFocus:
            // Center photo large, 3 smaller around edges
            // Layout: top-left small, top-right small, full-width center band, bottom small
            let sideH = (h - 2 * g) * 0.25
            let centerH = (h - 2 * g) * 0.5
            let cellW = (w - g) / 2
            return [
                CGRect(x: 0, y: 0, width: cellW, height: sideH),
                CGRect(x: cellW + g, y: 0, width: cellW, height: sideH),
                CGRect(x: 0, y: sideH + g, width: w, height: centerH),
                CGRect(x: 0, y: sideH + centerH + 2 * g, width: w, height: sideH)
            ]
        }
    }

    // MARK: - Drawing

    private static func drawImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, transform: PhotoTransform = .identity, context: CGContext) {
        context.saveGState()

        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.clip()

        var drawRect = aspectFillRect(for: image.size, in: rect)

        // Apply user's zoom (scale up from center of cell)
        if transform.scale > 1.0 {
            let newW = drawRect.width * transform.scale
            let newH = drawRect.height * transform.scale
            drawRect = CGRect(
                x: drawRect.midX - newW / 2,
                y: drawRect.midY - newH / 2,
                width: newW,
                height: newH
            )
        }

        // Apply user's pan offset (normalized: -1...1 maps to max overflow)
        let overflowX = (drawRect.width - rect.width) / 2
        let overflowY = (drawRect.height - rect.height) / 2
        drawRect.origin.x += transform.offset.width * overflowX
        drawRect.origin.y += transform.offset.height * overflowY

        image.draw(in: drawRect)

        context.restoreGState()
    }

    /// Draws the first image as an aspect-fill blurred background.
    private static func drawBlurredBackground(
        from image: UIImage?,
        in rect: CGRect,
        context: CGContext
    ) {
        guard let image = image, let ciImage = CIImage(image: image) else {
            UIColor.black.setFill()
            UIBezierPath(rect: rect).fill()
            return
        }

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ciImage
        blur.radius = 30

        guard let output = blur.outputImage else {
            UIColor.black.setFill()
            UIBezierPath(rect: rect).fill()
            return
        }

        // Crop to original extent (blur expands edges)
        let cropped = output.cropped(to: ciImage.extent)

        guard let cgBlurred = ciContext.createCGImage(cropped, from: ciImage.extent) else {
            UIColor.black.setFill()
            UIBezierPath(rect: rect).fill()
            return
        }

        let blurredUIImage = UIImage(cgImage: cgBlurred)
        let fillRect = aspectFillRect(for: blurredUIImage.size, in: rect)

        context.saveGState()
        context.addPath(UIBezierPath(rect: rect).cgPath)
        context.clip()
        blurredUIImage.draw(in: fillRect)
        context.restoreGState()
    }

    /// Calculates a rect that aspect-fills `imageSize` into `bounds`.
    private static func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        let boundsRatio = bounds.width / bounds.height

        var drawSize: CGSize
        if imageRatio > boundsRatio {
            drawSize = CGSize(width: bounds.height * imageRatio, height: bounds.height)
        } else {
            drawSize = CGSize(width: bounds.width, height: bounds.width / imageRatio)
        }

        let x = bounds.midX - drawSize.width / 2
        let y = bounds.midY - drawSize.height / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: drawSize)
    }
}
