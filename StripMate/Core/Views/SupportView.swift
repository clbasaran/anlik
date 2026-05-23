import SwiftUI
import StoreKit

// MARK: - Support View

struct SupportView: View {
    @AppStorage("show_support_warm_note") private var showWarmNote = true
    @State private var showMailError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if showWarmNote {
                    WarmNoteCard(
                        eyebrow: String(localized: "buradayız"),
                        title: String(localized: "yazdığın hiçbir şey boşluğa düşmüyor"),
                        message: String(localized: "sorun, fikir ya da kısa bir merhaba. hepsini gerçekten okuyoruz ve mümkün olduğunca hızlı dönüyoruz."),
                        dismissLabel: String(localized: "tamam"),
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showWarmNote = false
                            }
                        }
                    )
                }

                // Contact
                supportSection(title: String(localized: "iletişim")) {
                    Button {
                        sendSupportEmail()
                    } label: {
                        supportRow(icon: "envelope.fill", label: String(localized: "sorun bildir"), description: String(localized: "bize e-posta gönder"))
                    }
                    divider
                    Button {
                        sendFeatureEmail()
                    } label: {
                        supportRow(icon: "lightbulb.fill", label: String(localized: "özellik öner"), description: String(localized: "fikirlerini paylaş"))
                    }
                }
                
                // Rate
                supportSection(title: String(localized: "değerlendir")) {
                    Button {
                        requestAppReview()
                    } label: {
                        supportRow(icon: "star.fill", label: String(localized: "uygulamayı değerlendir"), description: String(localized: "app store'da bize yıldız ver"))
                    }
                }
                
                // FAQ
                supportSection(title: String(localized: "sık sorulan sorular")) {
                    faqItem(
                        question: String(localized: "arkadaşımı nasıl eklerim?"),
                        answer: String(localized: "arkadaş ekle bölümüne git ve arkadaşının 8 haneli davet kodunu gir. istersen qr kodunu da okutabilirsin.")
                    )
                    divider
                    faqItem(
                        question: String(localized: "fotoğraflarım ne kadar süre saklanır?"),
                        answer: String(localized: "fotoğraflar 30 gün boyunca saklanır. süre dolunca sistem onları otomatik olarak temizler.")
                    )
                    divider
                    faqItem(
                        question: String(localized: "bağ nasıl çalışır?"),
                        answer: String(localized: "her gün bir arkadaşına fotoğraf gönderdiğinde bağın büyür. 1 gün ara verirsen bağ devam eder, 2 gün ara verirsen sıfırlanır.")
                    )
                    divider
                    faqItem(
                        question: String(localized: "widget nasıl eklenir?"),
                        answer: String(localized: "ana ekranı basılı tut, sol üstteki + butonuna dokun, anlık. widget'ını bul ve istediğin boyutu seç.")
                    )
                    divider
                    faqItem(
                        question: String(localized: "hesabımı nasıl silerim?"),
                        answer: String(localized: "ayarlar → hesap yönetimi → hesabımı sil yolunu izle. bu işlem geri alınamaz ve verilerin kalıcı olarak silinir.")
                    )
                    divider
                    faqItem(
                        question: String(localized: "maksimum kaç arkadaş ekleyebilirim?"),
                        answer: String(localized: "en fazla 50 arkadaş ekleyebilirsin. anlık. küçük, yakın ve yönetilebilir bir çevre için tasarlandı.")
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(String(localized: "yardım ve destek"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert(String(localized: "e-posta uygulaması bulunamadı"), isPresented: $showMailError) {
            Button(String(localized: "tamam"), role: .cancel) {}
        } message: {
            Text(String(localized: "info@celalbasaran.com adresine doğrudan e-posta gönderebilirsin."))
        }
    }
    
    // MARK: - Components
    
    private func supportSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
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
    
    private func supportRow(icon: String, label: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 6)
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        DisclosureGroup {
            Text(answer)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 4)
                .padding(.bottom, 8)
        } label: {
            Text(question)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .tint(.white.opacity(0.25))
        .padding(.vertical, 4)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
    }
    
    // MARK: - Actions
    
    private func sendSupportEmail() {
        let subject = "anlık. — Sorun Bildirimi"
        let deviceInfo = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let body = "\n\n---\nCihaz: \(deviceInfo)\nUygulama: v\(appVersion)"
        
        let emailUrl = "mailto:info@celalbasaran.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: emailUrl), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailError = true
        }
    }
    
    private func sendFeatureEmail() {
        let subject = "anlık. — Özellik Önerisi"
        let emailUrl = "mailto:info@celalbasaran.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: emailUrl), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailError = true
        }
    }
    
    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            AppStore.requestReview(in: scene)
        }
    }
}
