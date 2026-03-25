import SwiftUI

struct HelpGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // MARK: - Nasıl Kullanılır
                    sectionBlock(title: "nasıl kullanılır") {
                        VStack(spacing: 12) {
                            stepCard(number: 1, icon: "camera.fill", title: "Fotoğraf çek", subtitle: "Kameranı aç ve anını yakala")
                            stepCard(number: 2, icon: "person.2.fill", title: "Arkadaş seç", subtitle: "Fotoğrafını görmesini istediğin arkadaşlarını seç")
                            stepCard(number: 3, icon: "paperplane.fill", title: "Gönder", subtitle: "Gönder butonuna bas, fotoğrafın anında ulaşsın")
                            stepCard(number: 4, icon: "flame.fill", title: "Seriyi koru", subtitle: "Her gün paylaşım yap, serin büyüsün")
                        }
                    }

                    // MARK: - Özellikler
                    sectionBlock(title: "özellikler") {
                        VStack(spacing: 12) {
                            featureCard(title: "Seri (Streak)", description: "Her gün karşılıklı fotoğraf paylaşarak seri oluştur")
                            featureCard(title: "Widget", description: "Ana ekranına widget ekle, arkadaşının son fotoğrafını anında gör")
                            featureCard(title: "Haftalık Özet", description: "Her hafta paylaşım istatistiklerini gör")
                            featureCard(title: "Çıkartmalar", description: "GIPHY çıkartmalarını mesajlara yapıştır")
                            featureCard(title: "Arkadaşlık Seviyeleri", description: "Streak'in arttıkça arkadaşlık seviyeniz yükselir")
                        }
                    }

                    // MARK: - Sık Sorulan Sorular
                    sectionBlock(title: "sık sorulan sorular") {
                        VStack(spacing: 0) {
                            faqItem(
                                question: "Fotoğraflarım ne kadar süre saklanıyor?",
                                answer: "30 gün boyunca"
                            )
                            faqItem(
                                question: "Arkadaşımı nasıl eklerim?",
                                answer: "8 haneli davet kodunu veya kullanıcı adını gir"
                            )
                            faqItem(
                                question: "Widget nasıl eklenir?",
                                answer: "Ana ekranı basılı tut \u{2192} Widget Ekle \u{2192} anlık. seç"
                            )
                            faqItem(
                                question: "Verilerim güvende mi?",
                                answer: "Tüm veriler Firebase altyapısında şifreli olarak saklanır"
                            )
                            faqItem(
                                question: "Hesabımı nasıl silerim?",
                                answer: "Ayarlar \u{2192} Hesabı Sil"
                            )
                        }
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // MARK: - Canlı Destek
                    sectionBlock(title: "canlı destek") {
                        NavigationLink {
                            SupportChatView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("canlı destek")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("bize yazın, en kısa sürede dönelim")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("yardım")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Section Block

    private func sectionBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)

            content()
        }
    }

    // MARK: - Step Card

    private func stepCard(number: Int, icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Feature Card

    private func featureCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - FAQ Item

    private func faqItem(question: String, answer: String) -> some View {
        DisclosureGroup {
            Text(answer)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
        } label: {
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .tint(.white.opacity(0.3))
    }
}
