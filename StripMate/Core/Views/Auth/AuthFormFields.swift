import SwiftUI
import UIKit

// MARK: - Auth Field Constants

/// Visual constants shared by every input on the auth screens (login, signup
/// wizard, reset-password sheet). Keeping them in one place stops the corner
/// radius and stroke colour from drifting between flows — visually small but
/// noticeable when the user moves from login → signup → reset.
enum AuthFieldStyle {
    static let cornerRadius: CGFloat = 12
    static let strokeColor: Color = Color.white.opacity(0.15)
    static let backgroundColor: Color = Color.white.opacity(0.08)
}

// MARK: - Reusable Auth Inputs

/// Bordered text field with a leading SF Symbol — the canonical look for any
/// auth input the app shows. Use this instead of inline TextField so the
/// styling, content type, and autocapitalization rules stay identical
/// across login, signup, and reset.
struct AuthTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let icon: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalize: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(AuthFieldStyle.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AuthFieldStyle.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuthFieldStyle.cornerRadius, style: .continuous)
                .stroke(AuthFieldStyle.strokeColor, lineWidth: 0.5)
        )
    }
}

/// Bordered SecureField sibling of AuthTextField. Same visual contract.
struct AuthSecureField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let icon: String
    var contentType: UITextContentType?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .textContentType(contentType)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(AuthFieldStyle.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AuthFieldStyle.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuthFieldStyle.cornerRadius, style: .continuous)
                .stroke(AuthFieldStyle.strokeColor, lineWidth: 0.5)
        )
    }
}

#Preview("AuthTextField") {
    @Previewable @State var email = ""
    return ZStack {
        Color.black.ignoresSafeArea()
        AuthTextField(
            placeholder: "e-posta",
            text: $email,
            icon: "envelope",
            contentType: .emailAddress,
            keyboardType: .emailAddress,
            autocapitalize: false
        )
        .padding()
    }
}

#Preview("AuthSecureField") {
    @Previewable @State var pwd = ""
    return ZStack {
        Color.black.ignoresSafeArea()
        AuthSecureField(
            placeholder: "şifre",
            text: $pwd,
            icon: "lock",
            contentType: .password
        )
        .padding()
    }
}
