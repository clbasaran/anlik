import SwiftUI

/// Centralized error alert modifier — standardizes error presentation across all views.
/// Usage: `.errorAlert(errorMessage: $viewModel.errorMessage)`
/// With retry: `.errorAlert(errorMessage: $viewModel.errorMessage, retryAction: viewModel.retry)`
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?
    var retryAction: (() -> Void)?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "Hata"),
                isPresented: isPresented,
                presenting: errorMessage
            ) { _ in
                if let retryAction {
                    Button("tekrar dene") {
                        errorMessage = nil
                        retryAction()
                    }
                    Button("iptal", role: .cancel) {
                        errorMessage = nil
                    }
                } else {
                    Button(String(localized: "Tamam"), role: .cancel) {
                        errorMessage = nil
                    }
                }
            } message: { message in
                Text(message)
            }
    }
}

extension View {
    /// Attach a standardized error alert to any view.
    func errorAlert(errorMessage: Binding<String?>, retryAction: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage, retryAction: retryAction))
    }
}
