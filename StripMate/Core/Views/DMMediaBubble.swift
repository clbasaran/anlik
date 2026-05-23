import SwiftUI

/// Renders a DM message whose body is a single media URL — either a GIF
/// (GIPHY/Tenor / .gif) or a photo uploaded via PhotosPicker (Firebase Storage
/// dm_photos URL). Replaces the plain text bubble with the actual media so the
/// recipient sees the GIF/photo, not a long URL string.
struct DMMediaBubble: View {
    let message: DirectMessage
    let isMe: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        content
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .onTapGesture(count: 2, perform: onDoubleTap)
            .contextMenu {
                if isMe {
                    Button(role: .destructive, action: onDelete) {
                        Label(String(localized: "mesajı sil"), systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive, action: onReport) {
                        Label(String(localized: "mesajı bildir"), systemImage: "exclamationmark.bubble")
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch DirectMessageView.dmMediaKind(message.text) {
        case .gif:
            AnimatedGIFView(url: message.text)
                .frame(width: 200, height: 200)
        case .image:
            CachedAsyncImage(
                url: URL(string: message.text),
                content: { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    Color.white.opacity(0.06)
                }
            )
            .frame(width: 220, height: 280)
        case .none:
            EmptyView()
        }
    }
}
