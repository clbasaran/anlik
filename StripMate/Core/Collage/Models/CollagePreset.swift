import SwiftUI

/// One of four hand-tuned collage presets. A preset is a complete look —
/// background, gap, corner radius, accent treatment — bundled together so
/// users pick a *character* rather than fiddling with five sliders.
///
/// Each preset is responsible for two things:
/// 1. Visual style (background, gap, corner) — exposed via `style`.
/// 2. Geometry per photo count — exposed via `frames(for:in:)` (CollageGeometry).
public enum CollagePreset: String, CaseIterable, Identifiable, Sendable {
    case klasik   // beyaz arkaplan, ince gap, keskin köşe — gazete/dergi
    case cerceve  // siyah arkaplan, geniş gap, yuvarlak köşe — polaroid
    case akis     // ilk fotonun blur'u arkaplan, no gap, keskin — sürekli akış
    case bant     // siyah arkaplan, no gap, ince beyaz ayraç — film şeridi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .klasik:  return "klasik"
        case .cerceve: return "çerçeve"
        case .akis:    return "akış"
        case .bant:    return "bant"
        }
    }

    /// One-line hint shown under the chip name so users can read what the
    /// preset *does* without having to tap each one.
    public var subtitle: String {
        switch self {
        case .klasik:  return "ince ayraç"
        case .cerceve: return "polaroid"
        case .akis:    return "blur arkaplan"
        case .bant:    return "film şeridi"
        }
    }

    /// Whether the user can flip the preset background between black and
    /// white. `akis` is locked to its blur background.
    public var supportsBackgroundOverride: Bool {
        switch self {
        case .klasik, .cerceve, .bant: return true
        case .akis:                    return false
        }
    }

    public var style: Style {
        switch self {
        case .klasik:
            return Style(background: .solid(.white), gap: 2, cornerRadius: 0, divider: nil)
        case .cerceve:
            return Style(background: .solid(.black), gap: 16, cornerRadius: 12, divider: nil)
        case .akis:
            return Style(background: .blurOfFirst, gap: 0, cornerRadius: 0, divider: nil)
        case .bant:
            return Style(background: .solid(.black), gap: 0, cornerRadius: 0,
                         divider: .init(color: .white, thickness: 1))
        }
    }

    public struct Style: Sendable {
        public let background: Background
        public let gap: CGFloat
        public let cornerRadius: CGFloat
        public let divider: Divider?

        public enum Background: Sendable {
            case solid(SolidColor)
            case blurOfFirst
        }
        public enum SolidColor: Sendable {
            case black, white
            var uiColor: UIColor {
                switch self {
                case .black: return .black
                case .white: return .white
                }
            }
        }
        public struct Divider: Sendable {
            public let color: SolidColor
            public let thickness: CGFloat
        }
    }

    /// Photo counts this preset gracefully supports. Renderer falls back to
    /// the closest supported count if more photos are passed than fit.
    public var supportedCounts: ClosedRange<Int> {
        switch self {
        case .klasik:  return 2...4
        case .cerceve: return 2...4
        case .akis:    return 2...4
        case .bant:    return 2...3   // 4 dikey şerit 9:16'da çok dar
        }
    }
}
