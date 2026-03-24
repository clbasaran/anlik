import SwiftUI

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Brand
                VStack(spacing: 12) {
                    Text("anlık.")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("anı yakala. paylaş. bağlan.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                    
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("sürüm \(version) (derleme \(build))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.2))
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 0) {
                    statItem(value: "50", label: "maks arkadaş")
                    statDivider
                    statItem(value: "30", label: "gün saklama")
                    statDivider
                    statItem(value: "∞", label: "an")
                }
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                
                // Links
                aboutSection(title: "yasal") {
                    Button {
                        openURL("https://celalbasaran.com/anlik/terms")
                    } label: {
                        linkRow(label: "kullanım koşulları")
                    }
                    divider
                    Button {
                        openURL("https://celalbasaran.com/anlik/privacy")
                    } label: {
                        linkRow(label: "gizlilik politikası")
                    }
                    divider
                    Button {
                        openURL("https://celalbasaran.com/anlik/kvkk")
                    } label: {
                        linkRow(label: "KVKK aydınlatma metni")
                    }
                }
                
                aboutSection(title: "açık kaynak") {
                    Button {
                        openURL("https://celalbasaran.com/anlik/licenses")
                    } label: {
                        linkRow(label: "açık kaynak lisansları")
                    }
                }
                
                // Credits
                VStack(spacing: 8) {
                    Text("❤️")
                        .font(.system(size: 28))
                    
                    Text("Celal Başaran tarafından geliştirildi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                    
                    Text("Muğla, Türkiye")
                        .font(.system(size: 12, weight: .medium))
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
                Text("hakkında")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - Components
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
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
    
    private func linkRow(label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 8)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
