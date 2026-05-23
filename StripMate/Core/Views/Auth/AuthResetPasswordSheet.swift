import SwiftUI

/// Standalone sheet for the "forgot password?" flow. Owns its own input and
/// in-flight state so AuthView doesn't have to drag four `@State` properties
/// around just for one optional path. Presented via `.sheet` from the login
/// view; dismisses itself on success.
struct AuthResetPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var message: String?
    @State private var error: String?
    @State private var isResetting: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "şifre sıfırla"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(String(localized: "e-postana şifre sıfırlama bağlantısı göndereceğiz."))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                AuthTextField(
                    placeholder: "Email",
                    text: $email,
                    icon: "envelope",
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocapitalize: false
                )
                .padding(.horizontal, 28)

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if let error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    Task { await sendReset() }
                } label: {
                    HStack {
                        if isResetting {
                            ProgressView().tint(.black)
                        } else {
                            Text(String(localized: "gönder"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AuthFieldStyle.cornerRadius, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 28)
                .disabled(isResetting)

                Spacer()
            }
            .padding(.top, 32)
        }
    }

    @MainActor
    private func sendReset() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = String(localized: "Lütfen e-posta adresini gir")
            return
        }
        isResetting = true
        error = nil
        message = nil
        do {
            try await DependencyContainer.shared.userRepository.sendPasswordReset(to: trimmed)
            message = String(localized: "Şifre sıfırlama e-postası gönderildi! Gelen kutunu kontrol et.")
            HapticsManager.playNotification(type: .success)
        } catch {
            self.error = String(localized: "Sıfırlama e-postası gönderilemedi.")
            HapticsManager.playNotification(type: .error)
        }
        isResetting = false
    }
}
