import SwiftUI
import WatchKit

/// Streak dashboard — shows all active streaks ranked by tier, with a detail
/// view per friend. Monochrome throughout: tier icons are SF Symbols rendered
/// in white, "expiring" state uses opacity instead of a warning color.
struct StreakDashboardView: View {
    @EnvironmentObject var store: WatchDataStore
    @State private var selectedStreak: WatchStreak?
    var onBack: (() -> Void)?

    var body: some View {
        if let streak = selectedStreak {
            streakDetail(streak)
        } else if store.streaks.isEmpty {
            emptyState
        } else {
            streakList
        }
    }

    // MARK: - Streak List

    private var streakList: some View {
        ScrollView {
            VStack(spacing: WatchBrand.Spacing.xxs) {
                backRow(label: String(localized: "watch.nav.home"))

                // Expiring soon — rendered with opacity emphasis rather than
                // an orange/yellow accent (brand rule: monochrome).
                ForEach(store.expiringStreaks) { streak in
                    Button { selectedStreak = streak } label: {
                        expiringRow(streak: streak)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(streak.friendName.isEmpty
                        ? String(localized: "watch.friend.placeholder")
                        : streak.friendName)
                    .accessibilityValue("\(streak.currentStreak) \(String(localized: "watch.count.day_suffix"))")
                    .accessibilityHint(String(localized: "watch.a11y.streak.row.hint"))
                }

                let nonExpiring = store.activeStreaks.filter { !$0.isExpiringSoon }
                ForEach(nonExpiring) { streak in
                    Button { selectedStreak = streak } label: {
                        StreakRowView(streak: streak)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(streak.friendName.isEmpty
                        ? String(localized: "watch.friend.placeholder")
                        : streak.friendName)
                    .accessibilityValue("\(streak.currentStreak) \(String(localized: "watch.count.day_suffix"))")
                    .accessibilityHint(String(localized: "watch.a11y.streak.row.hint"))
                }

                let inactive = store.streaks.filter { $0.currentStreak == 0 }
                if !inactive.isEmpty {
                    Text(String(localized: "watch.section.other"))
                        .font(WatchBrand.micro())
                        .foregroundStyle(WatchBrand.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, WatchBrand.Spacing.sm)
                        .padding(.leading, WatchBrand.Spacing.xxs)

                    ForEach(inactive) { streak in
                        Button { selectedStreak = streak } label: {
                            StreakRowView(streak: streak)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, WatchBrand.Spacing.xxs)
        }
        .navigationTitle(String(localized: "watch.section.streaks"))
    }

    private func expiringRow(streak: WatchStreak) -> some View {
        HStack(spacing: WatchBrand.Spacing.sm) {
            Image(systemName: "hourglass")
                .font(WatchBrand.body())
                .foregroundStyle(WatchBrand.textPrimary)
            Text(streak.friendName.isEmpty
                ? String(localized: "watch.friend.placeholder")
                : streak.friendName)
                .font(WatchBrand.headline(size: 13))
                .foregroundStyle(WatchBrand.textPrimary)
                .lineLimit(1)
            Spacer()
            HStack(spacing: WatchBrand.Spacing.hairline) {
                Text("\(streak.currentStreak)")
                    .font(WatchBrand.stat(size: 14))
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
            }
            .foregroundStyle(WatchBrand.textPrimary)
        }
        .padding(.vertical, WatchBrand.Spacing.xs)
        .padding(.horizontal, WatchBrand.Spacing.md)
        .background(WatchBrand.surfaceActive, in: RoundedRectangle(cornerRadius: WatchBrand.Radius.sm))
    }

    // MARK: - Detail

    private func streakDetail(_ streak: WatchStreak) -> some View {
        ScrollView {
            VStack(spacing: WatchBrand.Spacing.md) {
                backRow(label: String(localized: "watch.section.streaks"),
                        action: { selectedStreak = nil })

                Image(systemName: streak.tierEmoji)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(WatchBrand.textPrimary)

                Text(streak.friendName.isEmpty
                    ? String(localized: "watch.friend.placeholder")
                    : streak.friendName)
                    .font(WatchBrand.title(size: 15))
                    .foregroundStyle(WatchBrand.textPrimary)

                Text(streak.tierDisplayName)
                    .font(WatchBrand.micro())
                    .foregroundStyle(WatchBrand.textSecondary)

                ProgressView(value: streak.tierProgress)
                    .tint(WatchBrand.textPrimary.opacity(0.6))
                    .padding(.horizontal, WatchBrand.Spacing.xs)

                HStack {
                    Text("\(streak.friendshipScore)")
                        .font(WatchBrand.micro(size: 10))
                        .foregroundStyle(WatchBrand.textPrimary)
                    Spacer()
                    Text("\(streak.nextTierThreshold)")
                        .font(WatchBrand.micro(size: 10))
                        .foregroundStyle(WatchBrand.textTertiary)
                }
                .padding(.horizontal, WatchBrand.Spacing.xs)

                statsRow(streak: streak)

                if streak.isExpiringSoon {
                    expiringFooter
                }
            }
            .padding(.horizontal, WatchBrand.Spacing.xxs)
        }
    }

    private func statsRow(streak: WatchStreak) -> some View {
        HStack(spacing: WatchBrand.Spacing.lg) {
            statCell(systemImage: "flame.fill",
                     value: streak.currentStreak,
                     labelKey: "watch.stats.current")
            statCell(systemImage: "bolt.fill",
                     value: streak.longestStreak,
                     labelKey: "watch.stats.longest")
            statCell(systemImage: "camera.fill",
                     value: streak.totalExchanges,
                     labelKey: "watch.stats.total")
        }
        .padding(.top, WatchBrand.Spacing.xxs)
    }

    private func statCell(systemImage: String,
                          value: Int,
                          labelKey: String.LocalizationValue) -> some View {
        VStack(spacing: WatchBrand.Spacing.hairline) {
            Image(systemName: systemImage)
                .font(WatchBrand.micro())
                .foregroundStyle(WatchBrand.textPrimary)
            Text("\(value)")
                .font(WatchBrand.stat())
                .foregroundStyle(WatchBrand.textPrimary)
            Text(String(localized: labelKey))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(WatchBrand.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var expiringFooter: some View {
        VStack(spacing: WatchBrand.Spacing.xs) {
            HStack(spacing: WatchBrand.Spacing.xxs) {
                Image(systemName: "hourglass")
                    .font(WatchBrand.micro(size: 11))
                Text(String(localized: "watch.cta.share_today"))
                    .font(WatchBrand.micro(size: 11))
            }
            .foregroundStyle(WatchBrand.textPrimary)

            Button {
                PhoneSessionManager.shared.openCameraOnPhone()
            } label: {
                Label(String(localized: "watch.action.open_camera"), systemImage: "camera.fill")
                    .font(WatchBrand.caption())
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchBrand.textPrimary)
            .foregroundStyle(.black)
            .accessibilityLabel(String(localized: "watch.action.open_camera"))
            .accessibilityHint(String(localized: "watch.a11y.open_camera.hint"))
        }
        .padding(.top, WatchBrand.Spacing.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WatchBrand.Spacing.sm) {
            backRow(label: String(localized: "watch.nav.home"))

            Image(systemName: "flame.fill")
                .font(WatchBrand.title(size: 28))
                .foregroundStyle(WatchBrand.textTertiary)

            Text(String(localized: "watch.empty.streaks"))
                .font(WatchBrand.caption())
                .foregroundStyle(WatchBrand.textSecondary)

            Text(store.emptyStateHint)
                .font(WatchBrand.micro(size: 9))
                .foregroundStyle(WatchBrand.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                WatchDataStore.shared.markSyncStarted()
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Label(String(localized: "watch.action.refresh"), systemImage: "arrow.triangle.2.circlepath")
                    .font(WatchBrand.caption())
            }
            .buttonStyle(.bordered)
            .padding(.top, WatchBrand.Spacing.xxs)
        }
    }

    // MARK: - Back Row (shared)

    private func backRow(label: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Button {
                if let action {
                    action()
                } else {
                    onBack?()
                }
            } label: {
                HStack(spacing: WatchBrand.Spacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(label)
                        .font(WatchBrand.micro(size: 11))
                }
                .foregroundStyle(WatchBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "watch.a11y.back"))
            Spacer()
        }
        .padding(.bottom, WatchBrand.Spacing.xxs)
    }
}

// MARK: - Streak Row

struct StreakRowView: View {
    let streak: WatchStreak

    var body: some View {
        HStack(spacing: WatchBrand.Spacing.sm) {
            Image(systemName: streak.tierEmoji)
                .font(WatchBrand.body())
                .foregroundStyle(WatchBrand.textPrimary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: WatchBrand.Spacing.hairline) {
                Text(streak.friendName.isEmpty
                    ? String(localized: "watch.friend.placeholder")
                    : streak.friendName)
                    .font(WatchBrand.headline(size: 13))
                    .foregroundStyle(WatchBrand.textPrimary)
                    .lineLimit(1)

                Text(streak.tierDisplayName)
                    .font(WatchBrand.micro(size: 9))
                    .foregroundStyle(WatchBrand.textSecondary)
            }

            Spacer()

            if streak.currentStreak > 0 {
                HStack(spacing: WatchBrand.Spacing.hairline) {
                    Text("\(streak.currentStreak)")
                        .font(WatchBrand.stat(size: 14))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                }
                .foregroundStyle(WatchBrand.textPrimary)
            }
        }
        .padding(.vertical, WatchBrand.Spacing.xxs)
        .padding(.horizontal, WatchBrand.Spacing.xs)
    }
}

#Preview {
    StreakDashboardView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
