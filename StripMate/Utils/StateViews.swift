import SwiftUI

// MARK: - Loading State

/// Centred loading indicator with an optional caption. Uses the brand
/// monochrome language so screens don't feel jarring while data resolves.
public struct LoadingStateView: View {
    let label: String?

    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        VStack(spacing: Brand.Spacing.sm) {
            ProgressView()
                .tint(.white.opacity(0.55))
                .scaleEffect(0.95)

            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? String(localized: "yükleniyor"))
    }
}

// MARK: - Error State

/// Reusable error state for failed loads. Matches the empty-state language but
/// surfaces the error and a retry path. Mirrors EmptyStateView's visual
/// hierarchy so screens with multiple states feel consistent.
public struct ErrorStateView: View {
    let title: String
    let message: String?
    let retryLabel: String?
    let onRetry: (() -> Void)?

    public init(
        title: String = String(localized: "bir şey ters gitti."),
        message: String? = nil,
        retryLabel: String? = String(localized: "tekrar dene"),
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryLabel = retryLabel
        self.onRetry = onRetry
    }

    @State private var appeared = false

    public var body: some View {
        VStack(spacing: Brand.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.18))
                .scaleEffect(appeared ? 1.0 : 0.7)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: Brand.Spacing.xxs) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.22))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            if let retryLabel, let onRetry {
                Button {
                    HapticsManager.playImpact(style: .light)
                    onRetry()
                } label: {
                    Text(retryLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, Brand.Spacing.lg)
                        .padding(.vertical, Brand.Spacing.xs + 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.Spacing.xxxl + 12)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(Brand.Animations.standard.delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Phase Container

/// Single source of truth for the four canonical async phases. Use this
/// instead of hand-rolling `if isLoading { ... } else if let error { ... }`
/// branches in every screen — that pattern drifts and styling diverges.
///
/// ```swift
/// StateContainer(phase: viewModel.phase) { items in
///     List(items) { ... }
/// }
/// ```
public enum LoadPhase<Content> {
    case loading
    case empty
    case failed(message: String?)
    case loaded(Content)
}

public struct StateContainer<Content, Body: View>: View {
    let phase: LoadPhase<Content>
    let loadingLabel: String?
    let emptyIcon: String
    let emptyTitle: String
    let emptySubtitle: String?
    let emptyActionLabel: String?
    let onEmptyAction: (() -> Void)?
    let onRetry: (() -> Void)?
    let content: (Content) -> Body

    public init(
        phase: LoadPhase<Content>,
        loadingLabel: String? = nil,
        emptyIcon: String = "tray",
        emptyTitle: String = String(localized: "henüz bir şey yok."),
        emptySubtitle: String? = nil,
        emptyActionLabel: String? = nil,
        onEmptyAction: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Content) -> Body
    ) {
        self.phase = phase
        self.loadingLabel = loadingLabel
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptySubtitle = emptySubtitle
        self.emptyActionLabel = emptyActionLabel
        self.onEmptyAction = onEmptyAction
        self.onRetry = onRetry
        self.content = content
    }

    public var body: some View {
        switch phase {
        case .loading:
            LoadingStateView(label: loadingLabel)
        case .empty:
            EmptyStateView(
                icon: emptyIcon,
                title: emptyTitle,
                subtitle: emptySubtitle,
                actionLabel: emptyActionLabel,
                action: onEmptyAction
            )
        case .failed(let message):
            ErrorStateView(message: message, onRetry: onRetry)
        case .loaded(let value):
            content(value)
        }
    }
}
