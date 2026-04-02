import SwiftUI

/// Global error toast — monochrome, drops down from top, auto-dismisses.
/// Usage: `.errorToast($errorMessage)`
struct ErrorToastModifier: ViewModifier {
    @Binding var message: String?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    ErrorToastBanner(message: message) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            self.message = nil
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: message)
            .onChange(of: message) { _, newValue in
                guard newValue != nil else { return }
                // Cancel previous timer to avoid race conditions
                dismissTask?.cancel()
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.message = nil
                    }
                }
            }
    }
}

private struct ErrorToastBanner: View {
    let message: String
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
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
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
        .accessibilityLabel("Hata: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// Attach a global error toast that shows when `message` is non-nil.
    func errorToast(_ message: Binding<String?>) -> some View {
        modifier(ErrorToastModifier(message: message))
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
