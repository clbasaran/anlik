import SwiftUI

/// Centralized error alert modifier — standardizes error presentation across all views.
/// Usage: `.errorAlert(errorMessage: $viewModel.errorMessage)`
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?
    
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
                Button(String(localized: "Tamam"), role: .cancel) {
                    errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
    }
}

extension View {
    /// Attach a standardized error alert to any view.
    func errorAlert(errorMessage: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
}
