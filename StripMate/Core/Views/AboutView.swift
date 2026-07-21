import SwiftUI

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Brand
                VStack(spacing: 12) {
                    Text(String(localized: "anlık."))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text(String(localized: "anı yakala. paylaş. bağlan."))
                        .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.35))

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text(String(localized: "sürüm \(version) (derleme \(build))"))
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.2))
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 40)

                // Stats
                HStack(spacing: 0) {
                    statItem(value: "50", label: String(localized: "maks arkadaş"))
                    statDivider
                    statItem(value: "30", label: String(localized: "gün saklama"))
                    statDivider
                    statItem(value: "∞", label: String(localized: "an"))
                }
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )

                // Links
                aboutSection(title: String(localized: "yasal")) {
                    Button {
                        openURL("https://celalbasaran.com/anlik/terms")
                    } label: {
                        linkRow(label: String(localized: "kullanım koşulları"))
                    }
                    divider
                    Button {
                        openURL("https://celalbasaran.com/anlik/privacy")
                    } label: {
                        linkRow(label: String(localized: "gizlilik politikası"))
                    }
                    divider
                    Button {
                        openURL("https://celalbasaran.com/anlik/kvkk")
                    } label: {
                        linkRow(label: String(localized: "KVKK aydınlatma metni"))
                    }
                }

                aboutSection(title: String(localized: "açık kaynak")) {
                    Button {
                        openURL("https://celalbasaran.com/anlik/licenses")
                    } label: {
                        linkRow(label: String(localized: "açık kaynak lisansları"))
                    }
                }

                // 5651 Yer Sağlayıcı Bilgileri
                aboutSection(title: String(localized: "yer sağlayıcı bilgileri")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "5651 sayılı kanun kapsamında yer sağlayıcı olarak bilgilendirme:"))
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.4))

                        infoRow(title: String(localized: "yer sağlayıcı"), value: String(localized: "Celal Başaran (bireysel geliştirici)"))
                        infoRow(title: String(localized: "iletişim"), value: "celalba78@gmail.com")
                        infoRow(title: String(localized: "konum"), value: String(localized: "Muğla, Türkiye"))
                        infoRow(title: String(localized: "altyapı"), value: "Google Firebase (ABD)")
                        infoRow(title: String(localized: "trafik verisi saklama"), value: String(localized: "2 yıl"))

                        Text(String(localized: "Uygunsuz içerik bildirimi için uygulama içi bildirim özelliğini veya yukarıdaki e-posta adresini kullanabilirsiniz. İçerik kaldırma talepleri en geç 24 saat içinde değerlendirilir."))
                            .font(Brand.scaledFont(size: 11, weight: .regular, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                // Credits
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(Brand.scaledFont(size: 28, relativeTo: .title2))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(String(localized: "Celal Başaran tarafından geliştirildi"))
                        .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.25))

                    Text("Muğla, Türkiye")
                        .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.15))
                }
                .padding(.top, 16)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(String(localized: "hakkında"))
                    .font(Brand.scaledFont(size: 17, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Components

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Brand.scaledFont(size: 22, weight: .bold, relativeTo: .title3))
                .foregroundStyle(.white)
            Text(label)
                .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 0.5, height: 36)
    }

    private func aboutSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func linkRow(label: String) -> some View {
        HStack {
            Text(label)
                .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
