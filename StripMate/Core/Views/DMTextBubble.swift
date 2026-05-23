import SwiftUI

/// Plain-text DM message bubble. Extracted out of DirectMessageView so the
/// SwiftUI type-checker doesn't time out on the parent body.
struct DMTextBubble: View {
    let message: DirectMessage
    let isMe: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        Text(message.text)
            .font(.system(.body, weight: .medium))
            .foregroundColor(isMe ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(isMe ? 0.35 : 0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .onTapGesture(count: 2, perform: onDoubleTap)
            .contextMenu {
                if isMe {
                    Button(role: .destructive, action: onDelete) {
                        Label(String(localized: "mesajı sil"), systemImage: "trash")
                    }
                }
                Button {
                    UIPasteboard.general.string = message.text
                    HapticsManager.playNotification(type: .success)
                } label: {
                    Label(String(localized: "kopyala"), systemImage: "doc.on.doc")
                }
                if !isMe {
                    Divider()
                    Button(role: .destructive, action: onReport) {
                        Label(String(localized: "mesajı bildir"), systemImage: "exclamationmark.bubble")
                    }
                }
            }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isMe {
            Color.white
        } else {
            Color(white: 0.22)
        }
    }
}
