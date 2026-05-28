import SwiftUI

/// Global error toast — monochrome, drops down from top, auto-dismisses.
/// Usage: `.errorToast($errorMessage)` or `.errorToast($errorMessage, retry: { ... })`
struct ErrorToastModifier: ViewModifier {
    @Binding var message: String?
    var retry: (() -> Void)?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    ErrorToastBanner(
                        message: message,
                        retry: retry.map { action in {
                            self.dismissTask?.cancel()
                            withAnimation(Brand.Animations.fade) { self.message = nil }
                            action()
                        }},
                        onDismiss: {
                            withAnimation(Brand.Animations.fadeOutStandard) {
                                self.message = nil
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: message)
            .onChange(of: message) { _, newValue in
                guard newValue != nil else { return }
                // Cancel previous timer to avoid race conditions
                dismissTask?.cancel()
                // Keep toast visible longer when a retry action is offered
                let timeout: Duration = retry != nil ? .seconds(6) : .seconds(3)
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    withAnimation(Brand.Animations.fadeOutStandard) {
                        self.message = nil
                    }
                }
            }
    }
}

private struct ErrorToastBanner: View {
    let message: String
    var retry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 0)

            if let retry {
                Button {
                    HapticsManager.playImpact(style: .light)
                    retry()
                } label: {
                    Text(String(localized: "Yeniden dene"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18), in: Capsule())
                }
                .frame(minHeight: 44)
                .accessibilityLabel(String(localized: "Yeniden dene"))
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 24, height: 24)
                    )
            }
            .accessibilityLabel(String(localized: "Kapat"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// Attach a global error toast that shows when `message` is non-nil.
    func errorToast(_ message: Binding<String?>) -> some View {
        modifier(ErrorToastModifier(message: message, retry: nil))
    }

    /// Attach a global error toast with a "Retry" action button.
    func errorToast(_ message: Binding<String?>, retry: @escaping () -> Void) -> some View {
        modifier(ErrorToastModifier(message: message, retry: retry))
    }
}

// MARK: - Environment Key for child views to report errors

private struct GlobalErrorKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

extension EnvironmentValues {
    var globalError: Binding<String?> {
        get { self[GlobalErrorKey.self] }
        set { self[GlobalErrorKey.self] = newValue }
    }
}
