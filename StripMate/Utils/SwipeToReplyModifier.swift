import SwiftUI

/// Instagram-style swipe-to-reply gesture modifier.
/// Attach to a message row; when the user swipes right past the threshold, `onReply` fires.
/// Uses overlay + offset approach so the parent scroll/navigation is never affected.
struct SwipeToReplyModifier: ViewModifier {
    let onReply: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasTriggered = false

    private let threshold: CGFloat = 55
    private let maxOffset: CGFloat = 80

    func body(content: Content) -> some View {
        content
            .offset(x: clampedOffset)
            .animation(Brand.Animations.tap, value: dragOffset)
            .overlay(alignment: .leading) {
                // Reply arrow icon — appears behind message as it slides
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .offset(x: -8)
                    .allowsHitTesting(false)
            }
            .simultaneousGesture(replyGesture)
    }

    // MARK: - Computed

    private var clampedOffset: CGFloat {
        guard dragOffset > 0 else { return 0 }
        // Rubber-band effect past threshold
        if dragOffset > threshold {
            return threshold + (dragOffset - threshold) * 0.25
        }
        return dragOffset
    }

    private var iconScale: CGFloat {
        min(clampedOffset / threshold, 1.0)
    }

    private var iconOpacity: Double {
        Double(min(clampedOffset / (threshold * 0.5), 1.0))
    }

    // MARK: - Gesture

    private var replyGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                // If drag started near the left edge of screen, let navigation handle it
                guard value.startLocation.x > 50 else { return }

                let h = value.translation.width
                let v = abs(value.translation.height)

                // Only activate for clearly horizontal-right drags
                guard h > 8, v < h * 0.6 else { return }
                state = h
            }
            .onChanged { value in
                // If drag started near the left edge, ignore
                guard value.startLocation.x > 50 else { return }

                let h = value.translation.width
                let v = abs(value.translation.height)
                guard h > 8, v < h * 0.6 else { return }

                if h >= threshold && !hasTriggered {
                    hasTriggered = true
                    HapticsManager.playImpact(style: .medium)
                }
            }
            .onEnded { value in
                // If drag started near the left edge, ignore
                guard value.startLocation.x > 50 else {
                    hasTriggered = false
                    return
                }

                let h = value.translation.width
                let v = abs(value.translation.height)
                if hasTriggered && h > 8 && v < h * 0.6 {
                    onReply()
                }
                hasTriggered = false
            }
    }
}

extension View {
    func swipeToReply(onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReplyModifier(onReply: onReply))
    }
}
