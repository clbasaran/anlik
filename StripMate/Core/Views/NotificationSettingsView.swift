import SwiftUI

// MARK: - Notification Preferences State

@Observable
private final class NotificationSettingsState {
    var notifStrips: Bool { didSet { save("notif_strips", notifStrips) } }
    var notifComments: Bool { didSet { save("notif_comments", notifComments) } }
    var notifStripChat: Bool { didSet { save("notif_strip_chat", notifStripChat) } }
    var notifDMs: Bool { didSet { save("notif_dms", notifDMs) } }
    var notifSupport: Bool { didSet { save("notif_support", notifSupport) } }
    var notifFriends: Bool { didSet { save("notif_friends", notifFriends) } }
    var notifNudge: Bool { didSet { save("notif_nudge", notifNudge) } }
    var notifStreaks: Bool { didSet { save("notif_streaks", notifStreaks) } }
    var notifPrompts: Bool { didSet { save("notif_prompts", notifPrompts) } }
    var notifWeekly: Bool { didSet { save("notif_weekly", notifWeekly) } }
    var quietHoursEnabled: Bool { didSet { save("quiet_hours_enabled", quietHoursEnabled) } }
    var quietHoursStart: Int { didSet { UserDefaults.standard.set(quietHoursStart, forKey: "quiet_hours_start") } }
    var quietHoursEnd: Int { didSet { UserDefaults.standard.set(quietHoursEnd, forKey: "quiet_hours_end") } }

    init() {
        let d = UserDefaults.standard
        self.notifStrips = d.object(forKey: "notif_strips") as? Bool ?? true
        self.notifComments = d.object(forKey: "notif_comments") as? Bool ?? true
        self.notifStripChat = d.object(forKey: "notif_strip_chat") as? Bool ?? true
        self.notifDMs = d.object(forKey: "notif_dms") as? Bool ?? true
        self.notifSupport = d.object(forKey: "notif_support") as? Bool ?? true
        self.notifFriends = d.object(forKey: "notif_friends") as? Bool ?? true
        self.notifNudge = d.object(forKey: "notif_nudge") as? Bool ?? true
        self.notifStreaks = d.object(forKey: "notif_streaks") as? Bool ?? true
        self.notifPrompts = d.object(forKey: "notif_prompts") as? Bool ?? true
        self.notifWeekly = d.object(forKey: "notif_weekly") as? Bool ?? true
        self.quietHoursEnabled = d.bool(forKey: "quiet_hours_enabled")
        self.quietHoursStart = d.object(forKey: "quiet_hours_start") != nil ? d.integer(forKey: "quiet_hours_start") : 23
        self.quietHoursEnd = d.object(forKey: "quiet_hours_end") != nil ? d.integer(forKey: "quiet_hours_end") : 7
    }

    private func save(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @State private var showQuietHoursPicker = false
    @State private var state = NotificationSettingsState()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Activity Section
                notifSection(title: "aktivite") {
                    notifToggle(key: "notif_strips", binding: $state.notifStrips, label: "yeni anlar", icon: "camera.fill", description: "arkadaşların yeni bir an paylaştığında")
                    divider
                    notifToggle(key: "notif_comments", binding: $state.notifComments, label: "yorumlar", icon: "bubble.left.fill", description: "anlarına yorum yapıldığında")
                    divider
                    notifToggle(key: "notif_strip_chat", binding: $state.notifStripChat, label: "an sohbetleri", icon: "bubble.left.and.bubble.right.fill", description: "anlarındaki sohbetlerde yeni mesaj geldiğinde")
                }

                // Messages Section
                notifSection(title: "mesajlar") {
                    notifToggle(key: "notif_dms", binding: $state.notifDMs, label: "direkt mesajlar", icon: "envelope.fill", description: "yeni bir direkt mesaj aldığında")
                    divider
                    notifToggle(key: "notif_support", binding: $state.notifSupport, label: "destek yanıtları", icon: "headphones", description: "destek ekibinden yanıt geldiğinde")
                }

                // Social Section
                notifSection(title: "sosyal") {
                    notifToggle(key: "notif_friends", binding: $state.notifFriends, label: "arkadaşlık istekleri", icon: "person.badge.plus.fill", description: "yeni bir arkadaşlık isteği aldığında")
                    divider
                    notifToggle(key: "notif_nudge", binding: $state.notifNudge, label: "dürtmeler", icon: "hand.point.right.fill", description: "bir arkadaşın seni dürttüğünde")
                    divider
                    notifToggle(key: "notif_streaks", binding: $state.notifStreaks, label: "bağ uyarıları", icon: "flame.fill", description: "bağın sona ermek üzereyken")
                }

                // Prompts Section
                notifSection(title: "görevler") {
                    notifToggle(key: "notif_prompts", binding: $state.notifPrompts, label: "günün görevi", icon: "sparkles", description: "günlük fotoğraf görevi yayınlandığında")
                    divider
                    notifToggle(key: "notif_weekly", binding: $state.notifWeekly, label: "haftalık özet", icon: "chart.bar.fill", description: "pazar günleri haftalık istatistiklerin")
                }
                
                // Quiet Hours
                notifSection(title: "sessiz saatler") {
                    VStack(spacing: 16) {
                        quietHoursToggle
                        
                        if state.quietHoursEnabled {
                            quietHoursTimeRange
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Info text
                Text(String(localized: "bildirim tercihlerin hem bu cihazda hem de sunucuda saklanır. sessiz saatler aktifken hiçbir bildirim gönderilmez."))
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
                Text(String(localized: "bildirimler"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - Components
    
    private func notifSection(title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
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
    
    private func notifToggle(key: String, binding: Binding<Bool>, label: LocalizedStringResource, icon: String, description: LocalizedStringResource) -> some View {
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
                get: { binding.wrappedValue },
                set: { newValue in
                    binding.wrappedValue = newValue
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
                Text(String(localized: "sessiz saatler"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(String(localized: "belirli saatlerde bildirimleri sessize al"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { state.quietHoursEnabled },
                set: { newValue in
                    state.quietHoursEnabled = newValue
                    // Sync to Firestore for Cloud Functions
                    Task {
                        try? await AuthService.shared.updateNotificationPreference(key: "quiet_hours_enabled", enabled: newValue)
                        if newValue {
                            try? await AuthService.shared.syncQuietHours(start: state.quietHoursStart, end: state.quietHoursEnd)
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
            timePickerPill(label: "başlangıç", hourBinding: $state.quietHoursStart)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.15))

            timePickerPill(label: "bitiş", hourBinding: $state.quietHoursEnd)
        }
        .padding(.leading, 36)
    }
    
    private func timePickerPill(label: LocalizedStringResource, hourBinding: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.25))

            Menu {
                ForEach(0..<24, id: \.self) { hour in
                    Button("\(String(format: "%02d", hour)):00") {
                        hourBinding.wrappedValue = hour
                        // Sync to Firestore
                        Task {
                            try? await AuthService.shared.syncQuietHours(start: state.quietHoursStart, end: state.quietHoursEnd)
                        }
                    }
                }
            } label: {
                Text("\(String(format: "%02d", hourBinding.wrappedValue)):00")
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
