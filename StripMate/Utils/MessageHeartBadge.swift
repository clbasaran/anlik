import SwiftUI

/// Tiny ❤️ badge shown below a message bubble when it has heart reactions.
/// Used in both DM and strip chat message views.
struct MessageHeartBadge: View {
    let reactions: [String: String]?
    let currentUserId: String
    let isMyMessage: Bool

    private var heartCount: Int {
        reactions?.values.filter { $0 == "❤️" }.count ?? 0
    }

    var body: some View {
        if heartCount > 0 {
            HStack(spacing: 2) {
                Text("❤️")
                    .font(.system(size: 14))
                if heartCount > 1 {
                    Text("\(heartCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(white: 0.18))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }
}
