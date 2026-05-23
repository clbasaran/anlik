import SwiftUI

// MARK: - anlık. Brand System (watchOS)
//
// Mirror of `Brand` in the iOS target, sized down for the Apple Watch screen
// (38–49mm). Pure monochrome — white text on black, opacity variants for
// hierarchy. No accent colors, no gradients, no emoji.
//
// This file is compiled into BOTH the Watch app target and the
// `StripMateWatchWidgets` extension target (added as a shared source ref).
// Anything that touches user-visible color/typography on the watch must live
// here — never inline literals in views.

public enum WatchBrand {

    // MARK: - Brand Name

    /// Canonical brand logotype. Always lowercase with trailing period.
    public static let name = "anlık."

    // MARK: - Color Palette
    //
    // Watch faces sit on dark backgrounds by default. Stick to white + opacity
    // for everything except true error states (where red is the universal
    // semantic). Avoid orange / yellow / green tinting — those break the
    // monochrome identity even when they're "accent" colors.

    /// Primary foreground — crisp white.
    public static let textPrimary       = Color.white

    /// Secondary text — slightly dim. Use for friend tier labels, timestamps.
    public static let textSecondary     = Color.white.opacity(0.6)

    /// Tertiary text — placeholder, "no data" hints, empty-state captions.
    public static let textTertiary      = Color.white.opacity(0.35)

    /// Subtle surface lift — card backgrounds, list rows.
    public static let surface           = Color.white.opacity(0.08)

    /// Slightly stronger surface for the active/pressed state.
    public static let surfaceActive     = Color.white.opacity(0.14)

    /// Hairline stroke for glass-like card edges.
    public static let stroke            = Color.white.opacity(0.08)

    /// Reserved for actual error states only (sync unreachable, decode failed,
    /// etc.). Never used for "warnings" or "attention" — those use opacity.
    public static let error             = Color(red: 0.95, green: 0.30, blue: 0.30)

    /// Reserved for success confirmation (prompt completed, send succeeded).
    /// A muted teal that reads as "done" without screaming.
    public static let success           = Color(red: 0.40, green: 0.85, blue: 0.70)

    // MARK: - Typography (system font, watch-sized)
    //
    // Numbers are tighter than iOS because the watch screen is small and
    // SwiftUI's default sizing is too large for our information density.

    public static func logotype(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    /// Section / page title.
    public static func title(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Card title.
    public static func headline(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Body text.
    public static func body(size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Caption — metadata, timestamps, hints.
    public static func caption(size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Tiny label — secondary captions, badge counts.
    public static func micro(size: CGFloat = 9) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Stat numerals (streak count, longest count, etc.). Rounded design
    /// reads more naturally for stand-alone numbers on a small screen.
    public static func stat(size: CGFloat = 15) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing
    //
    // Tighter than iOS — watch UI density is higher and a 16pt gap reads as
    // wasted space on a 38mm screen.

    public enum Spacing {
        public static let hairline: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 18
    }

    // MARK: - Corner Radius

    public enum Radius {
        /// Tag / pill.
        public static let xs: CGFloat = 6
        /// Card / list row.
        public static let sm: CGFloat = 10
        /// Feature card.
        public static let md: CGFloat = 12
        /// Hero surface.
        public static let lg: CGFloat = 16
    }
}

// MARK: - Reusable Modifiers

/// Standard card row: surface background, rounded corners, content padding.
public struct WatchCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(WatchBrand.Spacing.md)
            .background(WatchBrand.surface, in: RoundedRectangle(cornerRadius: WatchBrand.Radius.md))
    }
}

public extension View {
    func watchCard() -> some View { modifier(WatchCardStyle()) }
}
