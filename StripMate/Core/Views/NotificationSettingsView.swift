import SwiftUI

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @State private var showQuietHoursPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Activity Section
                notifSection(title: "aktivite") {
                    notifToggle(key: "notif_strips", label: "yeni anlar", icon: "camera.fill", description: "arkadaşların yeni bir an paylaştığında")
                    divider
                    notifToggle(key: "notif_comments", label: "yorumlar", icon: "bubble.left.fill", description: "anlarına yorum yapıldığında")
                }
                
                // Messages Section
                notifSection(title: "mesajlar") {
                    notifToggle(key: "notif_dms", label: "direkt mesajlar", icon: "envelope.fill", description: "yeni bir direkt mesaj aldığında")
                }
                
                // Social Section
                notifSection(title: "sosyal") {
                    notifToggle(key: "notif_friends", label: "arkadaşlık istekleri", icon: "person.badge.plus.fill", description: "yeni bir arkadaşlık isteği aldığında")
                    divider
                    notifToggle(key: "notif_streaks", label: "seri uyarıları", icon: "flame.fill", description: "serin sona ermek üzereyken")
                }
                
                // Prompts Section
                notifSection(title: "görevler") {
                    notifToggle(key: "notif_prompts", label: "günün görevi", icon: "sparkles", description: "günlük fotoğraf görevi yayınlandığında")
                    divider
                    notifToggle(key: "notif_weekly", label: "haftalık özet", icon: "chart.bar.fill", description: "pazar günleri haftalık istatistiklerin")
                }
                
                // Quiet Hours
                notifSection(title: "sessiz saatler") {
                    VStack(spacing: 16) {
                        quietHoursToggle
                        
                        if UserDefaults.standard.bool(forKey: "quiet_hours_enabled") {
                            quietHoursTimeRange
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Info text
                Text("bildirim tercihlerin hem bu cihazda hem de sunucuda saklanır. sessiz saatler aktifken hiçbir bildirim gönderilmez.")
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
                Text("bildirimler")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - Components
    
    private func notifSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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
    
    private func notifToggle(key: String, label: String, icon: String, description: String) -> some View {
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
                    .lineLimit(1)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.object(forKey: key) as? Bool ?? true },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: key)
                    Task {
                        try? await AuthService.shared.updateNotificationPreference(key: key, enabled: newValue)
                    }
                }
            ))
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
    
    private var quietHoursToggle: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("sessiz saatler")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("belirli saatlerde bildirimleri sessize al")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "quiet_hours_enabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "quiet_hours_enabled")
                    if newValue {
                        // Default: 23:00 - 07:00
                        if UserDefaults.standard.object(forKey: "quiet_hours_start") == nil {
                            UserDefaults.standard.set(23, forKey: "quiet_hours_start")
                            UserDefaults.standard.set(7, forKey: "quiet_hours_end")
                        }
                    }
                    // Sync to Firestore for Cloud Functions
                    Task {
                        try? await AuthService.shared.updateNotificationPreference(key: "quiet_hours_enabled", enabled: newValue)
                        if newValue {
                            let start = UserDefaults.standard.integer(forKey: "quiet_hours_start")
                            let end = UserDefaults.standard.integer(forKey: "quiet_hours_end")
                            try? await AuthService.shared.syncQuietHours(start: start, end: end)
                        }
                    }
                }
            ))
            .tint(.white.opacity(0.5))
            .labelsHidden()
        }
    }
    
    private var quietHoursTimeRange: some View {
        HStack(spacing: 16) {
            timePickerPill(label: "başlangıç", key: "quiet_hours_start")
            
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.15))
            
            timePickerPill(label: "bitiş", key: "quiet_hours_end")
        }
        .padding(.leading, 36)
    }
    
    private func timePickerPill(label: String, key: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
            
            Menu {
                ForEach(0..<24, id: \.self) { hour in
                    Button("\(String(format: "%02d", hour)):00") {
                        UserDefaults.standard.set(hour, forKey: key)
                        // Sync to Firestore
                        Task {
                            let start = UserDefaults.standard.integer(forKey: "quiet_hours_start")
                            let end = UserDefaults.standard.integer(forKey: "quiet_hours_end")
                            try? await AuthService.shared.syncQuietHours(start: start, end: end)
                        }
                    }
                }
            } label: {
                Text("\(String(format: "%02d", UserDefaults.standard.integer(forKey: key))):00")
                    .font(.system(size: 14, design: .monospaced).weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
    }
}
