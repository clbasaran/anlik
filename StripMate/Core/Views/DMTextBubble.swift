import SwiftUI

/// Plain-text message bubble shared by both chat surfaces (DirectMessageView
/// and ChatView). Extracted out of DirectMessageView so the SwiftUI
/// type-checker doesn't time out on the parent body.
struct DMTextBubble: View {
    let text: String
    let isMe: Bool
    let showsContextMenu: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onDoubleTap: () -> Void

    /// DM surface — full bubble with the built-in delete/copy/report context menu.
    init(
        message: DirectMessage,
        isMe: Bool,
        onDelete: @escaping () -> Void,
        onReport: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void
    ) {
        self.init(
            text: message.text,
            isMe: isMe,
            showsContextMenu: true,
            onDelete: onDelete,
            onReport: onReport,
            onDoubleTap: onDoubleTap
        )
    }

    /// Generic surface (e.g. ChatView) — callers that attach their own
    /// context menu should leave `showsContextMenu` false.
    init(
        text: String,
        isMe: Bool,
        showsContextMenu: Bool = false,
        onDelete: @escaping () -> Void = {},
        onReport: @escaping () -> Void = {},
        onDoubleTap: @escaping () -> Void = {}
    ) {
        self.text = text
        self.isMe = isMe
        self.showsContextMenu = showsContextMenu
        self.onDelete = onDelete
        self.onReport = onReport
        self.onDoubleTap = onDoubleTap
    }

    var body: some View {
        if showsContextMenu {
            bubble
                .contextMenu { menuItems }
        } else {
            bubble
        }
    }

    private var bubble: some View {
        Text(text)
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
    }

    @ViewBuilder
    private var menuItems: some View {
        if isMe {
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "mesajı sil"), systemImage: "trash")
            }
        }
        Button {
            UIPasteboard.general.string = text
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

    @ViewBuilder
    private var bubbleBackground: some View {
        if isMe {
            Color.white
        } else {
            Color(white: 0.22)
        }
    }
}
