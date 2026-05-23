import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Composes a final collage UIImage from photos + preset + per-photo
/// transforms. Single entry point: `render(state:)`. Designed to run on a
/// background thread — caller is responsible for that.
public enum CollageRenderer {

    /// Canvas size for rendered output. anlık. only ships 9:16 portrait, so
    /// this is the only canvas. 1080×1920 = 2.07 MP, plenty for messaging.
    public static let canvasSize = CGSize(width: 1080, height: 1920)

    /// Renders the collage. Returns nil only when the photo count is
    /// invalid for the preset (caller should have prevented this).
    public static func render(state: CollageState) -> UIImage? {
        let photos = state.photos
        guard !photos.isEmpty,
              state.preset.supportedCounts.contains(photos.count) else {
            return nil
        }
        let frames = CollageGeometry.frames(
            for: state.preset,
            count: photos.count,
            in: canvasSize
        )
        guard frames.count == photos.count else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let style = state.effectiveStyle
        return renderer.image { ctx in
            autoreleasepool {
                drawBackground(style, firstPhoto: photos.first!, in: CGRect(origin: .zero, size: canvasSize), context: ctx.cgContext)

                for (idx, frame) in frames.enumerated() {
                    let img = photos[idx]
                    let transform = state.transforms[idx] ?? .identity
                    drawPhoto(img, in: frame, transform: transform, cornerRadius: style.cornerRadius, context: ctx.cgContext)
                }

                if let divider = style.divider {
                    drawDividers(frames: frames, divider: divider, in: ctx.cgContext)
                }
            }
        }
    }

    // MARK: - Background

    private static func drawBackground(_ style: CollagePreset.Style, firstPhoto: UIImage, in rect: CGRect, context: CGContext) {
        switch style.background {
        case .solid(let color):
            color.uiColor.setFill()
            UIBezierPath(rect: rect).fill()
        case .blurOfFirst:
            if let blurred = cachedBlur(of: firstPhoto) {
                let fill = aspectFillRect(for: blurred.size, in: rect)
                context.saveGState()
                context.addPath(UIBezierPath(rect: rect).cgPath)
                context.clip()
                blurred.draw(in: fill)
                context.restoreGState()
            } else {
                UIColor.black.setFill()
                UIBezierPath(rect: rect).fill()
            }
        }
    }

    // MARK: - Photo

    private static func drawPhoto(_ image: UIImage, in cell: CGRect, transform: CollagePhotoTransform, cornerRadius: CGFloat, context: CGContext) {
        // Aspect-fill draw rect inside cell.
        let baseFill = aspectFillRect(for: image.size, in: cell)
        // Apply zoom (centered) + pan (normalized -1...1 against overflow).
        let scaledW = baseFill.width * transform.scale
        let scaledH = baseFill.height * transform.scale
        let overflowX = max(0, (scaledW - cell.width) / 2)
        let overflowY = max(0, (scaledH - cell.height) / 2)
        let panX = transform.offset.width * overflowX
        let panY = transform.offset.height * overflowY
        let drawRect = CGRect(
            x: cell.midX - scaledW / 2 + panX,
            y: cell.midY - scaledH / 2 + panY,
            width: scaledW,
            height: scaledH
        )

        context.saveGState()
        if cornerRadius > 0 {
            UIBezierPath(roundedRect: cell, cornerRadius: cornerRadius).addClip()
        } else {
            UIBezierPath(rect: cell).addClip()
        }
        image.draw(in: drawRect)
        context.restoreGState()
    }

    // MARK: - Dividers (bant preset)

    private static func drawDividers(frames: [CGRect], divider: CollagePreset.Style.Divider, in context: CGContext) {
        guard frames.count > 1 else { return }
        divider.color.uiColor.setStroke()
        context.setLineWidth(divider.thickness)
        for i in 1..<frames.count {
            let prev = frames[i - 1]
            let curr = frames[i]
            // Frames are stacked vertically in `bant`; draw a horizontal line
            // at the boundary.
            let y = (prev.maxY + curr.minY) / 2
            context.move(to: CGPoint(x: prev.minX, y: y))
            context.addLine(to: CGPoint(x: prev.maxX, y: y))
            context.strokePath()
        }
    }

    // MARK: - Aspect-fill helper

    private static func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        let boundsRatio = bounds.width / bounds.height
        if imageRatio > boundsRatio {
            // Image is wider: pin height, overflow horizontally.
            let h = bounds.height
            let w = h * imageRatio
            return CGRect(x: bounds.midX - w / 2, y: bounds.minY, width: w, height: h)
        } else {
            let w = bounds.width
            let h = w / imageRatio
            return CGRect(x: bounds.minX, y: bounds.midY - h / 2, width: w, height: h)
        }
    }

    // MARK: - Blur cache (for akis preset)

    private static var blurCache: [String: UIImage] = [:]
    private static let blurCacheLock = NSLock()
    private static let blurCacheLimit = 4
    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func cachedBlur(of image: UIImage) -> UIImage? {
        let key = "\(Int(image.size.width))x\(Int(image.size.height))|\(image.cgImage.map { ObjectIdentifier($0).hashValue } ?? 0)"
        blurCacheLock.lock()
        if let hit = blurCache[key] {
            blurCacheLock.unlock()
            return hit
        }
        blurCacheLock.unlock()

        // Downsample to 512px before blur — visually identical after
        // aspect-fill, ~8x faster on older devices.
        let down = downsample(image, max: 512)
        guard let ci = CIImage(image: down) else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ci
        filter.radius = 22
        guard let out = filter.outputImage,
              let cg = sharedCIContext.createCGImage(out.cropped(to: ci.extent), from: ci.extent) else {
            return nil
        }
        let result = UIImage(cgImage: cg)

        blurCacheLock.lock()
        if blurCache.count >= blurCacheLimit, let firstKey = blurCache.keys.first {
            blurCache.removeValue(forKey: firstKey)
        }
        blurCache[key] = result
        blurCacheLock.unlock()
        return result
    }

    private static func downsample(_ image: UIImage, max: CGFloat) -> UIImage {
        let longest = Swift.max(image.size.width, image.size.height)
        guard longest > max else { return image }
        let ratio = max / longest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
