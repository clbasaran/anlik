import SwiftUI

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

    /// Legacy — kept for compatibility but all point to monochrome
    public static let accent       = Color.white
    public static let meshBase     = Color.black
    public static let meshOrb1     = Color.black
    public static let meshOrb2     = Color.black

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
    
    // MARK: - Dynamic Type Support
    
    /// Scaled font that respects Dynamic Type settings while maintaining design hierarchy.
    /// Uses `.relativeTo:` to scale proportionally with system text sizes.
    public static func scaledFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    
    /// Title scaled font — scales with `.title2`
    public static func scaledTitle(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    
    /// Caption scaled font — scales with `.caption`
    public static func scaledCaption(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
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

/// Conditionally applies animation based on Reduce Motion setting
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: any Equatable & Sendable
    
    func body(content: Content) -> some View {
        content
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
