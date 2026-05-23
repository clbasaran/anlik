import SwiftUI
import WatchKit

/// Root view — flat, switch-driven navigation. No NavigationStack to avoid
/// nested-navigation crashes that watchOS occasionally throws when a sheet
/// presents over an active stack.
///
/// Deep links from complications use `stripmate://watch/<page>` and land
/// here via `.onOpenURL` to flip `currentPage`.
struct ContentView: View {
    @EnvironmentObject var store: WatchDataStore
    @State private var currentPage: WatchPage = .home

    enum WatchPage: String {
        case home, streaks, photo, prompt
    }

    var body: some View {
        Group {
            switch currentPage {
            case .home:
                homeList
            case .streaks:
                StreakDashboardView(onBack: { currentPage = .home })
                    .environmentObject(store)
            case .photo:
                LatestPhotoView(onBack: { currentPage = .home })
                    .environmentObject(store)
            case .prompt:
                DailyPromptCardView(onBack: { currentPage = .home })
                    .environmentObject(store)
            }
        }
        .onOpenURL(perform: handleDeepLink)
    }

    /// Complication tap deep links: `stripmate://watch/streaks` etc.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "stripmate", url.host == "watch" else { return }
        let path = url.pathComponents.dropFirst().first ?? ""
        switch path {
        case "streaks": currentPage = .streaks
        case "photo":   currentPage = .photo
        case "prompt":  currentPage = .prompt
        default:        currentPage = .home
        }
    }

    // MARK: - Home List

    private var homeList: some View {
        ScrollView {
            VStack(spacing: WatchBrand.Spacing.xs) {
                header
                syncBar
                cardButton(
                    titleKey: "watch.section.streaks",
                    systemImage: "flame.fill",
                    detail: store.totalActiveStreakCount > 0
                        ? "\(store.totalActiveStreakCount) \(String(localized: "watch.count.active_suffix"))"
                        : nil,
                    accessibilityValue: streakAccessibilityValue
                ) {
                    currentPage = .streaks
                }
                cardButton(
                    titleKey: "watch.section.latest_photo",
                    systemImage: "camera.fill",
                    detail: photoSubtitle,
                    accessibilityValue: photoSubtitle
                ) {
                    currentPage = .photo
                }
                cardButton(
                    titleKey: "watch.section.daily_prompt",
                    systemImage: "lightbulb.fill",
                    detail: store.dailyPrompt?.promptText,
                    accessibilityValue: store.dailyPrompt?.promptText
                ) {
                    currentPage = .prompt
                }
                if !store.expiringStreaks.isEmpty {
                    expiringBadge
                }
            }
            .padding(.horizontal, WatchBrand.Spacing.xxs)
        }
        .onAppear {
            store.refreshSyncState()
        }
    }

    // MARK: - Pieces

    private var header: some View {
        Text(WatchBrand.name)
            .font(WatchBrand.logotype(size: 18))
            .foregroundStyle(WatchBrand.textTertiary)
            .padding(.bottom, WatchBrand.Spacing.hairline)
            .accessibilityHidden(true)
    }

    private var syncBar: some View {
        HStack(spacing: WatchBrand.Spacing.xs) {
            Circle()
                .fill(store.syncStatusColor)
                .frame(width: 6, height: 6)
            Text(store.syncStatusLabel)
                .font(WatchBrand.micro())
                .foregroundStyle(WatchBrand.textSecondary)
                .lineLimit(1)
            Spacer(minLength: WatchBrand.Spacing.xxs)
            Button {
                WatchDataStore.shared.markSyncStarted()
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: store.syncState == .syncing
                      ? "arrow.triangle.2.circlepath.circle.fill"
                      : "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WatchBrand.textPrimary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "watch.action.refresh"))
        }
        .padding(.bottom, WatchBrand.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func cardButton(
        titleKey: String.LocalizationValue,
        systemImage: String,
        detail: String?,
        accessibilityValue: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: WatchBrand.Spacing.md) {
                Image(systemName: systemImage)
                    .font(WatchBrand.title(size: 16))
                    .foregroundStyle(WatchBrand.textPrimary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: WatchBrand.Spacing.hairline) {
                    Text(String(localized: titleKey))
                        .font(WatchBrand.headline())
                        .foregroundStyle(WatchBrand.textPrimary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(WatchBrand.micro(size: 10))
                            .foregroundStyle(WatchBrand.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WatchBrand.textTertiary)
            }
            .watchCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: titleKey))
        .accessibilityValue(accessibilityValue ?? "")
    }

    private var expiringBadge: some View {
        HStack(spacing: WatchBrand.Spacing.xxs) {
            Image(systemName: "hourglass")
                .font(WatchBrand.micro())
                .foregroundStyle(WatchBrand.textSecondary)
            Text("\(store.expiringStreaks.count) \(String(localized: "watch.count.expiring_suffix"))")
                .font(WatchBrand.micro(size: 11))
                .foregroundStyle(WatchBrand.textSecondary)
        }
        .padding(.top, WatchBrand.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Accessibility helpers

    private var streakAccessibilityValue: String {
        guard store.totalActiveStreakCount > 0 else { return "" }
        return "\(store.totalActiveStreakCount) \(String(localized: "watch.count.active_suffix"))"
    }

    private var photoSubtitle: String? {
        guard let photo = store.latestPhotos.first else { return nil }
        if !photo.senderName.isEmpty {
            return photo.senderName
        }
        return nil
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataStore.shared)
}
