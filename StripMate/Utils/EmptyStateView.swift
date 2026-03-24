import SwiftUI

/// Reusable empty state component for "anlık." monochrome design language.
/// Usage: `EmptyStateView(icon: "bell.slash", title: "henüz bildirim yok", subtitle: "yeni bir an paylaş.", actionLabel: "fotoğraf çek", action: { ... })`
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.15))
                .scaleEffect(appeared ? 1.0 : 0.6)
                .opacity(appeared ? 1 : 0)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            
            if let actionLabel, let action {
                Button {
                    HapticsManager.playImpact(style: .light)
                    action()
                } label: {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}
