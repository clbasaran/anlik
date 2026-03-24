import SwiftUI

// MARK: - Appearance Settings View

struct AppearanceSettingsView: View {
    @AppStorage("feed_layout") private var feedLayout: String = "single"
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("sound_enabled") private var soundEnabled: Bool = true
    @AppStorage("auto_save_photos") private var autoSavePhotos: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Feed Layout
                appearanceSection(title: "feed düzeni") {
                    HStack(spacing: 12) {
                        layoutOption(
                            icon: "square.grid.2x2.fill",
                            label: "grid",
                            isSelected: feedLayout == "grid"
                        ) {
                            feedLayout = "grid"
                            HapticsManager.playSelection()
                        }
                        
                        layoutOption(
                            icon: "rectangle.grid.1x2.fill",
                            label: "tek sütun",
                            isSelected: feedLayout == "single"
                        ) {
                            feedLayout = "single"
                            HapticsManager.playSelection()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // App Icon
                appearanceSection(title: "uygulama ikonu") {
                    HStack(spacing: 16) {
                        appIconOption(name: nil, label: "varsayılan")
                        appIconOption(name: "AppIconWhite", label: "beyaz")
                        appIconOption(name: "AppIconMinimal", label: "minimal")
                    }
                    .padding(.vertical, 4)
                }
                
                // Interactions
                appearanceSection(title: "etkileşim") {
                    toggleRow(
                        icon: "hand.tap.fill",
                        label: "dokunmatik geri bildirim",
                        description: "titreşim efektleri",
                        isOn: $hapticsEnabled
                    )
                    divider
                    toggleRow(
                        icon: "speaker.wave.2.fill",
                        label: "ses efektleri",
                        description: "kamera ve gönderim sesleri",
                        isOn: $soundEnabled
                    )
                }
                
                // Camera
                appearanceSection(title: "kamera") {
                    toggleRow(
                        icon: "square.and.arrow.down.fill",
                        label: "fotoğrafları otomatik kaydet",
                        description: "çekilen fotoğraflar galeri'ye kaydedilir",
                        isOn: $autoSavePhotos
                    )
                }
                
                // Info
                Text("görünüm ayarların yalnızca bu cihazda geçerlidir.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("görünüm")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - Components
    
    private func appearanceSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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
    
    private func layoutOption(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.25))
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.04), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func appIconOption(name: String?, label: String) -> some View {
        Button {
            UIApplication.shared.setAlternateIconName(name)
            HapticsManager.playNotification(type: .success)
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(name == nil ? Color.white.opacity(0.08) : (name == "AppIconWhite" ? Color.white.opacity(0.9) : Color.white.opacity(0.04)))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("a.")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(name == "AppIconWhite" ? .black : .white.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .buttonStyle(.plain)
    }
    
    private func toggleRow(icon: String, label: String, description: String, isOn: Binding<Bool>) -> some View {
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
            
            Toggle("", isOn: isOn)
                .tint(.white.opacity(0.5))
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }
}
