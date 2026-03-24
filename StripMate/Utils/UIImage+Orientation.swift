import UIKit
import ImageIO

extension UIImage {
    /// Returns a new image with normalized orientation (.up).
    /// Always re-draws the image to produce pixel-correct output
    /// regardless of EXIF orientation metadata.
    /// This fixes the common iOS issue where photos appear rotated/sideways
    /// when the EXIF orientation tag is not handled by the renderer.
    nonisolated func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized
    }
    
    /// Creates a properly oriented UIImage from raw JPEG/PNG data.
    /// Reads EXIF orientation directly from the data via CGImageSource,
    /// then re-draws the pixels so the resulting UIImage is always `.up`.
    /// This is more reliable than UIImage(data:) which sometimes fails
    /// to apply EXIF orientation correctly.
    static func orientationCorrectedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return UIImage(data: data)
        }
        
        // Read EXIF orientation from metadata
        // Check root level first, then TIFF dictionary as fallback
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        var exifOrientation: UInt32 = 1
        
        if let orient = properties?[kCGImagePropertyOrientation as String] as? UInt32 {
            exifOrientation = orient
        } else if let tiffDict = properties?[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
                  let orient = tiffDict[kCGImagePropertyTIFFOrientation as String] as? UInt32 {
            exifOrientation = orient
        }
        
        // Map CGImage EXIF orientation (1-8) to UIImage.Orientation
        let uiOrientation: UIImage.Orientation
        switch exifOrientation {
        case 1: uiOrientation = .up
        case 2: uiOrientation = .upMirrored
        case 3: uiOrientation = .down
        case 4: uiOrientation = .downMirrored
        case 5: uiOrientation = .leftMirrored
        case 6: uiOrientation = .right
        case 7: uiOrientation = .rightMirrored
        case 8: uiOrientation = .left
        default: uiOrientation = .up
        }
        
        // If already up, also try UIImage(data:) approach as double-check
        if uiOrientation == .up {
            // Even if EXIF says "up", UIImage(data:) might detect orientation differently
            let uiImage = UIImage(data: data)
            if let uiImage = uiImage, uiImage.imageOrientation != .up {
                return uiImage.normalizedOrientation()
            }
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        }
        
        // Create UIImage with correct orientation, then flatten pixels
        let oriented = UIImage(cgImage: cgImage, scale: 1.0, orientation: uiOrientation)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: oriented.size, format: format)
        let normalized = renderer.image { _ in
            oriented.draw(in: CGRect(origin: .zero, size: oriented.size))
        }
        return normalized
    }
    
    /// Resize image so the longest edge is at most `dimension` pixels.
    /// Returns the original image if already smaller.
    func resizedToMax(dimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > dimension else { return self }
        
        let scale = dimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
