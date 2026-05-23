import SwiftUI
import WatchKit

/// Today's photo challenge / prompt. Tapping the CTA opens the iPhone camera.
struct DailyPromptCardView: View {
    @EnvironmentObject var store: WatchDataStore
    var onBack: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: WatchBrand.Spacing.sm) {
                backRow

                if let prompt = store.dailyPrompt {
                    promptContent(prompt)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, WatchBrand.Spacing.xxs)
        }
    }

    // MARK: - Prompt Content

    private func promptContent(_ prompt: WatchPrompt) -> some View {
        VStack(spacing: WatchBrand.Spacing.sm) {
            HStack {
                Text(String(localized: "watch.prompt.header"))
                    .font(WatchBrand.micro(size: 9))
                    .foregroundStyle(WatchBrand.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if prompt.isCompletedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WatchBrand.micro())
                        .foregroundStyle(WatchBrand.success)
                        .accessibilityLabel(String(localized: "watch.prompt.completed"))
                }
            }

            Spacer(minLength: WatchBrand.Spacing.xs)

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(WatchBrand.textPrimary)

            Text(prompt.promptText)
                .font(WatchBrand.headline(size: 13))
                .foregroundStyle(WatchBrand.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)

            Spacer(minLength: WatchBrand.Spacing.xs)

            if !prompt.isCompletedToday {
                Button {
                    PhoneSessionManager.shared.openCameraOnPhone()
                } label: {
                    HStack(spacing: WatchBrand.Spacing.xxs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                        Text(String(localized: "watch.action.capture"))
                            .font(WatchBrand.caption())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchBrand.textPrimary)
                .foregroundStyle(.black)
                .accessibilityHint(String(localized: "watch.a11y.open_camera.hint"))
            } else {
                HStack(spacing: WatchBrand.Spacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "watch.prompt.completed"))
                }
                .font(WatchBrand.micro(size: 11))
                .foregroundStyle(WatchBrand.success.opacity(0.85))
            }
        }
        .padding(.horizontal, WatchBrand.Spacing.sm)
        .padding(.vertical, WatchBrand.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WatchBrand.Spacing.sm) {
            Image(systemName: "lightbulb")
                .font(WatchBrand.title(size: 24))
                .foregroundStyle(WatchBrand.textTertiary)

            Text(String(localized: "watch.empty.prompt"))
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
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(WatchBrand.micro())
            }
            .buttonStyle(.plain)
            .foregroundStyle(WatchBrand.textTertiary)
            .accessibilityLabel(String(localized: "watch.action.refresh"))
        }
        .padding(.top, WatchBrand.Spacing.md)
    }

    // MARK: - Back

    private var backRow: some View {
        HStack {
            Button {
                onBack?()
            } label: {
                HStack(spacing: WatchBrand.Spacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(localized: "watch.nav.home"))
                        .font(WatchBrand.micro(size: 11))
                }
                .foregroundStyle(WatchBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "watch.a11y.back"))
            Spacer()
        }
    }
}

#Preview {
    DailyPromptCardView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
