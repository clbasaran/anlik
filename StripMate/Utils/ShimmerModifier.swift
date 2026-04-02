import SwiftUI

/// A shimmer effect modifier for skeleton loading states.
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

/// Placeholder skeleton views for common layouts.
public struct SkeletonStripCard: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.white.opacity(0.08))
                .frame(height: 350)
            
            HStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 80, height: 10)
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.04))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
        .modifier(ShimmerModifier())
    }
}

public struct SkeletonFriendRow: View {
    public init() {}
    
    public var body: some View {
        HStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 90, height: 10)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(width: 44, height: 44)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
        .modifier(ShimmerModifier())
    }
}

extension View {
    /// Apply shimmer loading effect
    public func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Message Row (DM chat)

public struct SkeletonMessageRow: View {
    let isRight: Bool

    public init(isRight: Bool) {
        self.isRight = isRight
    }

    public var body: some View {
        HStack {
            if isRight { Spacer(minLength: 80) }

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .frame(
                    width: isRight ? 180 : 220,
                    height: isRight ? 36 : 48
                )

            if !isRight { Spacer(minLength: 80) }
        }
        .padding(.horizontal, 16)
        .modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Inbox Row

public struct SkeletonInboxRow: View {
    public init() {}
    
    public var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 180, height: 11)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
                .frame(width: 36, height: 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Notification Row

public struct SkeletonNotificationRow: View {
    public init() {}
    
    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 200, height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 10)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .modifier(ShimmerModifier())
    }
}
