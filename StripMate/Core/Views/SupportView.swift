import SwiftUI
import StoreKit

// MARK: - Support View

struct SupportView: View {
    @State private var showMailError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Contact
                supportSection(title: "iletişim") {
                    Button {
                        sendSupportEmail()
                    } label: {
                        supportRow(icon: "envelope.fill", label: "sorun bildir", description: "bize e-posta gönder")
                    }
                    divider
                    Button {
                        sendFeatureEmail()
                    } label: {
                        supportRow(icon: "lightbulb.fill", label: "özellik öner", description: "fikirlerini paylaş")
                    }
                }
                
                // Rate
                supportSection(title: "değerlendir") {
                    Button {
                        requestAppReview()
                    } label: {
                        supportRow(icon: "star.fill", label: "uygulamayı değerlendir", description: "App Store'da bize yıldız ver")
                    }
                }
                
                // FAQ
                supportSection(title: "sık sorulan sorular") {
                    faqItem(
                        question: "arkadaşımı nasıl eklerim?",
                        answer: "arkadaş ekle bölümüne git ve arkadaşının 8 haneli davet kodunu gir. ya da QR kodunu taratabilirsin."
                    )
                    divider
                    faqItem(
                        question: "fotoğraflarım ne kadar süre saklanır?",
                        answer: "fotoğraflar 30 gün boyunca saklanır. bu süre sonunda otomatik olarak silinir."
                    )
                    divider
                    faqItem(
                        question: "seri (streak) nasıl çalışır?",
                        answer: "her gün bir arkadaşına fotoğraf gönderdiğinde serin artar. 1 gün atlarsın seriye devam edersin, 2 gün atlarsan serin sıfırlanır."
                    )
                    divider
                    faqItem(
                        question: "widget nasıl eklenir?",
                        answer: "ana ekranı basılı tut → sol üstteki + butonuna bas → anlık. uygulamasını bul → istediğin boyutu seç."
                    )
                    divider
                    faqItem(
                        question: "hesabımı nasıl silerim?",
                        answer: "ayarlar → hesap yönetimi → hesabımı sil. bu işlem geri alınamaz ve tüm verilerin kalıcı olarak silinir."
                    )
                    divider
                    faqItem(
                        question: "maksimum kaç arkadaş ekleyebilirim?",
                        answer: "en fazla 50 arkadaş ekleyebilirsin. anlık. küçük ve samimi bir paylaşım alanı olmayı hedefler."
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
                Text("yardım ve destek")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("e-posta uygulaması bulunamadı", isPresented: $showMailError) {
            Button("tamam", role: .cancel) {}
        } message: {
            Text("info@celalbasaran.com adresine doğrudan e-posta gönderebilirsin.")
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
