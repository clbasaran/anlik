import SwiftUI
import UIKit

// MARK: - anlık. Brand System

/// Centralized brand tokens for the "anlık." identity.
/// Pure monochrome palette — no accent colors, no gradients.
public enum Brand {

    // MARK: - Brand Name
    
    /// The canonical brand logotype. Always lowercase with trailing period.
    public static let name = "anlık."

    // MARK: - Color Palette

    /// Pure OLED black — primary background.
    public static let black        = Color(red: 0, green: 0, blue: 0)
    
    /// Apple system dark gray (#1C1C1E) — cards, elevated surfaces.
    public static let darkGray     = Color.white.opacity(0.08)
    
    /// Subtle surface for input fields — almost invisible lift.
    public static let surfaceInput = Color.white.opacity(0.08)
    
    /// Border / stroke for glassmorphism elements.
    public static let strokeLight  = Color.white.opacity(0.08)
    
    /// Secondary text, placeholders.
    public static let textSecondary = Color.white.opacity(0.45)
    
    /// Primary text — crisp white.
    public static let textPrimary  = Color.white

    // MARK: - Typography (all .system)

    /// Brand logotype — large, bold, geometric.
    public static func logotype(size: CGFloat = 42) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    
    /// Headline — used for section titles.
    public static func headline(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    
    /// Body text.
    public static func body(size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    
    /// Caption / metadata text.
    public static func caption(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    // MARK: - Button Styles (monochrome)
    
    /// Primary action button gradient — subtle accent tone.
    public static let buttonGradient = LinearGradient(
        colors: [Color.white, Color.white],
        startPoint: .leading, endPoint: .trailing
    )
    /// Dark button gradient for secondary actions.
    public static let buttonGradientDark = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: - Spacing Scale
    //
    // Use these instead of inline padding numbers. The scale is geometric (×1.5)
    // so layouts read consistently and a future tightening/loosening can happen
    // in one place. When a layout truly needs an oddball value, prefer adding
    // a new named token here over an inline literal — that's the signal that a
    // pattern is emerging and deserves a name.

    public enum Spacing {
        /// 2pt — hairline gap between tightly-paired elements.
        public static let hairline: CGFloat = 2
        /// 4pt — micro gap, e.g. icon ↔ text within a tag.
        public static let xxs: CGFloat = 4
        /// 8pt — list row internal padding, small button gaps.
        public static let xs: CGFloat = 8
        /// 12pt — secondary action padding, form field gutter.
        public static let sm: CGFloat = 12
        /// 16pt — default card / screen edge padding.
        public static let md: CGFloat = 16
        /// 20pt — between major sections inside a card.
        public static let lg: CGFloat = 20
        /// 24pt — between cards on a screen.
        public static let xl: CGFloat = 24
        /// 32pt — between a header and its first content row.
        public static let xxl: CGFloat = 32
        /// 48pt — full-screen state padding (empty / loading / error).
        public static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius Scale

    public enum Radius {
        /// 6pt — chip / pill stroke.
        public static let xs: CGFloat = 6
        /// 10pt — secondary card / list row.
        public static let sm: CGFloat = 10
        /// 14pt — default card.
        public static let md: CGFloat = 14
        /// 18pt — feature card / sheet detent.
        public static let lg: CGFloat = 18
        /// 24pt — hero surface.
        public static let xl: CGFloat = 24
    }

    // MARK: - Animation Presets
    //
    // Centralised so durations and damping factors don't drift across screens.
    // Pair with `animationAccessible(_:value:)` to honour Reduce Motion.

    public enum Animations {
        /// Snappy spring for taps and small UI shifts.
        public static let snap: Animation = .spring(response: 0.3, dampingFraction: 0.78)
        /// Default spring for transitions, sheets, drawers.
        public static let standard: Animation = .spring(response: 0.42, dampingFraction: 0.82)
        /// Soft spring for opening/closing large surfaces.
        public static let soft: Animation = .spring(response: 0.55, dampingFraction: 0.88)
        /// Linear ease for opacity-only transitions.
        public static let fade: Animation = .easeOut(duration: 0.2)
    }

    // MARK: - Dynamic Type Support

    /// Scaled font that respects Dynamic Type settings while maintaining design hierarchy.
    /// Uses `UIFontMetrics` to scale proportionally with system text sizes.
    public static func scaledFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        let uiWeight = uiFontWeight(from: weight)
        let uiTextStyle = uiTextStyle(from: textStyle)
        let baseFont = UIFont.systemFont(ofSize: size, weight: uiWeight)
        let scaledFont = UIFontMetrics(forTextStyle: uiTextStyle).scaledFont(for: baseFont)
        return Font(scaledFont)
    }

    /// Title scaled font — scales with `.title2`
    public static func scaledTitle(size: CGFloat = 22) -> Font {
        let baseFont = UIFont.systemFont(ofSize: size, weight: .bold)
        let scaledFont = UIFontMetrics(forTextStyle: .title2).scaledFont(for: baseFont)
        return Font(scaledFont)
    }

    /// Caption scaled font — scales with `.caption`
    public static func scaledCaption(size: CGFloat = 12) -> Font {
        let baseFont = UIFont.systemFont(ofSize: size, weight: .medium)
        let scaledFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
        return Font(scaledFont)
    }

    // MARK: - UIKit Bridging Helpers

    private static func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func uiTextStyle(from textStyle: Font.TextStyle) -> UIFont.TextStyle {
        switch textStyle {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

// MARK: - Dynamic Type View Modifier

/// Ensures text never clips by adding minimumScaleFactor for Dynamic Type
struct DynamicTypeModifier: ViewModifier {
    let minScale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .minimumScaleFactor(minScale)
            .lineLimit(nil)
    }
}

// MARK: - Reduce Motion Support (P0 Accessibility)

/// Conditionally removes animations when Reduce Motion is enabled
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                }
            }
    }
}

extension View {
    /// Apply Dynamic Type safety — prevents text clipping at largest accessibility sizes
    func dynamicTypeAccessible(minScale: CGFloat = 0.7) -> some View {
        modifier(DynamicTypeModifier(minScale: minScale))
    }
    
    /// Animation that respects Reduce Motion accessibility setting
    func animationAccessible<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(AccessibleAnimationModifier(animation: animation, value: value))
    }
}

struct AccessibleAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : animation, value: value)
    }
}
