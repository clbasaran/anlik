import SwiftUI

/// "Arkadaş bulamıyorsan" yardım sheet'i. FriendGateView'dan çekildi —
/// stateless ve pure presentational, ayrı dosyada test edilmesi ve gelecekte
/// yardım kartı eklemek (rehberden bul, beta linki, vs.) bu dosyada
/// büyümesi daha temiz.
struct FriendGateHelpSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "arkadaş bulamıyorsan"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            row(
                icon: "qrcode",
                title: String(localized: "QR kodunu paylaş"),
                text: String(localized: "yanındaki arkadaşına QR'ı göster, tarasın.")
            )
            row(
                icon: "message.fill",
                title: String(localized: "mesajla gönder"),
                text: String(localized: "WhatsApp veya iMessage ile davet kodunu at.")
            )
            row(
                icon: "person.crop.circle.badge.plus",
                title: String(localized: "rehberden bul"),
                text: String(localized: "kişilerini tarayıp hangi arkadaşının app'te olduğunu gör.")
            )
            row(
                icon: "clock.fill",
                title: String(localized: "birazdan tekrar dene"),
                text: String(localized: "arkadaşın app'i henüz indirmediyse 1-2 gün bekleyebilirsin.")
            )

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FriendGateHelpSheet()
    }
}
