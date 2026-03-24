import SwiftUI

/// Lightweight model describing an in-app notification banner.
struct InAppBanner: Equatable {
    let title: String
    let body: String
    let icon: String          // SF Symbol name
    let deepLink: URL?        // Optional tap action
    
    static func == (lhs: InAppBanner, rhs: InAppBanner) -> Bool {
        lhs.title == rhs.title && lhs.body == rhs.body && lhs.deepLink == rhs.deepLink
    }
}

/// A toast-style banner that slides down from the top with haptic feedback.
/// Dismisses automatically after 3 seconds or on tap / swipe-up.
struct InAppBannerView: View {
    let banner: InAppBanner
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = -150
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: banner.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(banner.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
        .padding(.horizontal, 12)
        .offset(y: offset + dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
            dismissBanner()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        dismissBanner()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            HapticsManager.playNotification(type: .success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                offset = 0
            }
            // Auto-dismiss after 3.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                dismissBanner()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(banner.title): \(banner.body)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "Açmak için çift dokun, kapatmak için yukarı kaydır"))
    }
    
    private func dismissBanner() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            offset = -150
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}
