import SwiftUI

/// Tiny heart badge shown below a message bubble when it has heart reactions.
/// Used in both DM and strip chat message views.
struct MessageHeartBadge: View {
    let reactions: [String: String]?
    let currentUserId: String
    let isMyMessage: Bool

    private static let heartValue = "\u{2764}\u{FE0F}" // red heart emoji stored in Firestore

    private var heartCount: Int {
        reactions?.values.filter { $0 == Self.heartValue }.count ?? 0
    }

    var body: some View {
        if heartCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
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
