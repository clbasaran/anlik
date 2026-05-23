import CoreGraphics

/// Resolves the placement of N photos for a given preset on a canvas.
/// Each preset has a hand-tuned layout per supported photo count — no
/// procedural "auto" layouts, since opinionated decisions look better than
/// CSS-grid math at small N.
///
/// Canvas is always assumed to be 9:16 portrait (the only aspect anlık.
/// supports). Frames are returned in the preset's painting order.
public enum CollageGeometry {

    /// Returns the cell rectangles for `count` photos under `preset` on a
    /// canvas of `size`. Always returns exactly `count` rects. If the preset
    /// doesn't support that count, falls back to the closest supported count.
    public static func frames(
        for preset: CollagePreset,
        count: Int,
        in size: CGSize
    ) -> [CGRect] {
        let safeCount = max(2, min(count, preset.supportedCounts.upperBound))
        let gap = preset.style.gap

        switch preset {
        case .klasik:   return klasikFrames(count: safeCount, in: size, gap: gap)
        case .cerceve:  return cerceveFrames(count: safeCount, in: size, gap: gap)
        case .akis:     return akisFrames(count: safeCount, in: size, gap: gap)
        case .bant:     return bantFrames(count: safeCount, in: size, gap: gap)
        }
    }

    // MARK: - klasik (eşit alanlar, gazete hissi)

    private static func klasikFrames(count: Int, in size: CGSize, gap: CGFloat) -> [CGRect] {
        switch count {
        case 2:
            // Üst yarı / alt yarı, ince gap araya
            let h = (size.height - gap) / 2
            return [
                CGRect(x: 0, y: 0, width: size.width, height: h),
                CGRect(x: 0, y: h + gap, width: size.width, height: h)
            ]
        case 3:
            // Üstte 1 büyük, altta 2 yan yana
            let topH = size.height * 0.55 - gap / 2
            let botH = size.height - topH - gap
            let botW = (size.width - gap) / 2
            return [
                CGRect(x: 0, y: 0, width: size.width, height: topH),
                CGRect(x: 0, y: topH + gap, width: botW, height: botH),
                CGRect(x: botW + gap, y: topH + gap, width: botW, height: botH)
            ]
        case 4:
            // 2x2 eşit grid
            let cw = (size.width - gap) / 2
            let ch = (size.height - gap) / 2
            return [
                CGRect(x: 0, y: 0, width: cw, height: ch),
                CGRect(x: cw + gap, y: 0, width: cw, height: ch),
                CGRect(x: 0, y: ch + gap, width: cw, height: ch),
                CGRect(x: cw + gap, y: ch + gap, width: cw, height: ch)
            ]
        default:
            return []
        }
    }

    // MARK: - çerçeve (siyah arkaplanlı, geniş gap, yuvarlak köşe)

    private static func cerceveFrames(count: Int, in size: CGSize, gap: CGFloat) -> [CGRect] {
        // Wider gap means we also want some padding from the canvas edges
        // so cells aren't kissing the rounded outer corners.
        let pad = gap
        let inner = CGRect(x: pad, y: pad, width: size.width - 2 * pad, height: size.height - 2 * pad)

        switch count {
        case 2:
            let h = (inner.height - gap) / 2
            return [
                CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: h),
                CGRect(x: inner.minX, y: inner.minY + h + gap, width: inner.width, height: h)
            ]
        case 3:
            // Üstte 2 yan yana, altta 1 geniş
            let topW = (inner.width - gap) / 2
            let topH = inner.height * 0.45 - gap / 2
            let botH = inner.height - topH - gap
            return [
                CGRect(x: inner.minX, y: inner.minY, width: topW, height: topH),
                CGRect(x: inner.minX + topW + gap, y: inner.minY, width: topW, height: topH),
                CGRect(x: inner.minX, y: inner.minY + topH + gap, width: inner.width, height: botH)
            ]
        case 4:
            let cw = (inner.width - gap) / 2
            let ch = (inner.height - gap) / 2
            return [
                CGRect(x: inner.minX, y: inner.minY, width: cw, height: ch),
                CGRect(x: inner.minX + cw + gap, y: inner.minY, width: cw, height: ch),
                CGRect(x: inner.minX, y: inner.minY + ch + gap, width: cw, height: ch),
                CGRect(x: inner.minX + cw + gap, y: inner.minY + ch + gap, width: cw, height: ch)
            ]
        default:
            return []
        }
    }

    // MARK: - akış (asimetrik, blur arkaplanlı)

    private static func akisFrames(count: Int, in size: CGSize, gap: CGFloat) -> [CGRect] {
        switch count {
        case 2:
            // 1 büyük üstte (yüksek), 1 küçük altta — asimetrik vurgu
            let topH = size.height * 0.65
            let botH = size.height - topH
            return [
                CGRect(x: 0, y: 0, width: size.width, height: topH),
                CGRect(x: 0, y: topH, width: size.width, height: botH)
            ]
        case 3:
            // Sol büyük yatay (full-height), sağda 2 küçük dikey
            let leftW = size.width * 0.6
            let rightW = size.width - leftW
            let rightH = size.height / 2
            return [
                CGRect(x: 0, y: 0, width: leftW, height: size.height),
                CGRect(x: leftW, y: 0, width: rightW, height: rightH),
                CGRect(x: leftW, y: rightH, width: rightW, height: rightH)
            ]
        case 4:
            // 1 büyük üstte, 3 küçük şerit altta
            let topH = size.height * 0.6
            let botH = size.height - topH
            let botW = size.width / 3
            return [
                CGRect(x: 0, y: 0, width: size.width, height: topH),
                CGRect(x: 0, y: topH, width: botW, height: botH),
                CGRect(x: botW, y: topH, width: botW, height: botH),
                CGRect(x: 2 * botW, y: topH, width: botW, height: botH)
            ]
        default:
            return []
        }
    }

    // MARK: - bant (film şeridi, eşit yatay dilimler)

    private static func bantFrames(count: Int, in size: CGSize, gap: CGFloat) -> [CGRect] {
        // Bant yalnızca 2-3 destekler; her hücre tam genişlik, eşit yükseklik.
        let strips = max(2, min(count, 3))
        let h = size.height / CGFloat(strips)
        return (0..<strips).map { i in
            CGRect(x: 0, y: CGFloat(i) * h, width: size.width, height: h)
        }
    }
}
