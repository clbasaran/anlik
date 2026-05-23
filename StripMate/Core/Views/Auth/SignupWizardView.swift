import SwiftUI
import AuthenticationServices

/// Three-step signup wizard. Pulled out of `AuthView` so that view focuses on
/// the login surface; the wizard now owns its own step machine, consent
/// state, avatar picker state, and password-strength helpers.
///
/// The parent passes:
/// - `viewModel`: the shared AuthViewModel that drives the actual signup call.
/// - `onCancel`: tapped from the back chevron when on step 0 — usually flips
///   the parent to the login view.
/// - `onPresentLegalDocument`: shown when the user taps a consent link.
///   Parent owns the LegalDocumentView sheet so it can be reused in other
///   surfaces too.
struct SignupWizardView: View {
    @Bindable var viewModel: AuthViewModel
    var onCancel: () -> Void
    var onPresentLegalDocument: (LegalDocument) -> Void

    // Wizard-local state — none of this belongs to the parent.
    @State private var signupStep: Int = 0
    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedKVKK = false
    @State private var acceptedEULA = false
    @State private var selectedAvatarImage: UIImage?
    @State private var showAvatarPicker = false

    private let totalSignupSteps = 3
    private let fieldCorner: CGFloat = AuthFieldStyle.cornerRadius
    private let fieldStroke: Color = AuthFieldStyle.strokeColor

    private var allConsentsAccepted: Bool {
        acceptedTerms && acceptedPrivacy && acceptedKVKK && acceptedEULA
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                Group {
                    switch signupStep {
                    case 0: signupStepEmail
                    case 1: signupStepProfile
                    case 2: signupStepConsents
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: signupStep)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            // Toggle to login
            Button {
                HapticsManager.playSelection()
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.errorMessage = nil
                    signupStep = 0
                    onCancel()
                }
            } label: {
                Text(String(localized: "zaten hesabın var mı? giriş yap"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPhotoPicker { image in
                selectedAvatarImage = image
            }
            .presentationBackground(.black)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                HapticsManager.playImpact(style: .light)
                if signupStep > 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        signupStep -= 1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.errorMessage = nil
                        onCancel()
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(signupStep > 0 ? String(localized: "Geri") : String(localized: "Giriş ekranına dön"))

            // Step progress capsules
            HStack(spacing: 4) {
                ForEach(0..<totalSignupSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= signupStep ? Color.white : Color.white.opacity(0.15))
                        .frame(height: 3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: signupStep)
                }
            }

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Step 0: Email & Password

    private var signupStepEmail: some View {
        VStack(spacing: 20) {
            stepHeader(
                title: String(localized: "hesabını oluştur"),
                subtitle: String(localized: "başlangıç için e-posta ve şifren yeter")
            )

            VStack(spacing: 14) {
                AuthTextField(
                    placeholder: "e-posta",
                    text: $viewModel.email,
                    icon: "envelope",
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocapitalize: false
                )

                if !viewModel.email.isEmpty {
                    let email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isValid = isValidEmail(email)
                    HStack(spacing: 6) {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isValid ? .white.opacity(0.7) : .white.opacity(0.35))
                        Text(isValid ? String(localized: "geçerli e-posta") : String(localized: "geçersiz e-posta formatı"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isValid ? .white.opacity(0.7) : .white.opacity(0.35))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isValid)
                }

                AuthSecureField(
                    placeholder: "şifre",
                    text: $viewModel.password,
                    icon: "lock",
                    contentType: .newPassword
                )

                if !viewModel.password.isEmpty {
                    passwordStrengthView
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            nextButton(
                enabled: canAdvanceStep0,
                action: {
                    HapticsManager.playImpact(style: .medium)
                    AnalyticsService.shared.log(.signupStepCompleted, parameters: ["step": 0])
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        signupStep = 1
                    }
                }
            )

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                Text(String(localized: "veya"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
            }

            // Apple Sign In
            SignInWithAppleButton(.continue) { request in
                let nonce = viewModel.startAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = viewModel.sha256(nonce)
            } onCompletion: { result in
                Task { await viewModel.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        }
    }

    // MARK: - Step 1: Profile Info

    private var signupStepProfile: some View {
        VStack(spacing: 20) {
            stepHeader(
                title: String(localized: "profilini oluştur"),
                subtitle: String(localized: "yakınların seni kolayca tanısın")
            )

            // Compact optional avatar picker — tap to add; can be skipped.
            Button {
                HapticsManager.playSelection()
                showAvatarPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let image = selectedAvatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 88, height: 88)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: selectedAvatarImage == nil ? "plus" : "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(String(localized: "Profil fotoğrafı ekle (opsiyonel)"))

            if selectedAvatarImage == nil {
                Text(String(localized: "profil fotoğrafı opsiyonel — sonra da ekleyebilirsin"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            VStack(spacing: 14) {
                AuthTextField(
                    placeholder: "ad soyad",
                    text: $viewModel.displayName,
                    icon: "person",
                    contentType: .name
                )

                AuthTextField(
                    placeholder: "kullanıcı adı",
                    text: $viewModel.username,
                    icon: "at",
                    contentType: .username,
                    autocapitalize: false
                )

                DatePicker(
                    String(localized: "doğum tarihi"),
                    selection: $viewModel.dateOfBirth,
                    in: ...AppLimits.latestAllowedBirthDate,
                    displayedComponents: .date
                )
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
            }

            nextButton(
                enabled: canAdvanceStep1,
                action: {
                    HapticsManager.playImpact(style: .medium)
                    AnalyticsService.shared.log(.signupStepCompleted, parameters: ["step": 1])
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        signupStep = 2
                    }
                }
            )
        }
    }

    // MARK: - Step 2: Consents

    private var signupStepConsents: some View {
        VStack(spacing: 20) {
            stepHeader(
                title: String(localized: "neredeyse tamam!"),
                subtitle: String(localized: "hesabın hazır, son onayı ver")
            )

            VStack(spacing: 10) {
                consentCheckbox(
                    title: String(localized: "Kullanım Koşulları"),
                    isAccepted: $acceptedTerms,
                    document: .termsOfService
                )
                consentCheckbox(
                    title: String(localized: "Gizlilik Politikası"),
                    isAccepted: $acceptedPrivacy,
                    document: .privacyPolicy
                )
                consentCheckbox(
                    title: String(localized: "KVKK Aydınlatma Metni"),
                    isAccepted: $acceptedKVKK,
                    document: .kvkk
                )
                consentCheckbox(
                    title: String(localized: "EULA"),
                    isAccepted: $acceptedEULA,
                    document: .eula
                )

                // Select all
                Button {
                    HapticsManager.playImpact(style: .light)
                    let newVal = !allConsentsAccepted
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        acceptedTerms = newVal
                        acceptedPrivacy = newVal
                        acceptedKVKK = newVal
                        acceptedEULA = newVal
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: allConsentsAccepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(allConsentsAccepted ? .white : .white.opacity(0.3))
                        Text(String(localized: "tümünü okudum ve kabul ediyorum"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 4)
            }

            // Status Messages
            if viewModel.showSuccessMessage {
                Text(String(localized: "kayıt başarılı! yönlendiriliyorsun..."))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Final signup button
            Button {
                HapticsManager.playImpact(style: .medium)
                AnalyticsService.shared.log(.signupStepCompleted, parameters: ["step": 2])
                Task {
                    await viewModel.completeEmailSignUp(avatarImage: selectedAvatarImage)
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text(String(localized: "hesap oluştur"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(allConsentsAccepted ? .black : .black.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(allConsentsAccepted ? Color.white : Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!allConsentsAccepted || viewModel.isLoading)
            .accessibilityLabel(String(localized: "hesap oluştur"))
        }
    }

    // MARK: - Validation

    /// Minimum 8 chars and at least 2 of: digit, symbol, uppercase. Keeps the
    /// bar low enough to not block signup but rejects trivial passwords like
    /// "password" or "123456".
    private func isStrongEnoughPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasDigit = password.contains(where: { $0.isNumber })
        let hasSymbol = password.contains(where: { !$0.isLetter && !$0.isNumber })
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let categories = [hasDigit, hasSymbol, hasUppercase].filter { $0 }.count
        return categories >= 2
    }

    private var canAdvanceStep0: Bool {
        let email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValidEmail(email) && isStrongEnoughPassword(viewModel.password)
    }

    private var canAdvanceStep1: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        AppLimits.meetsMinimumRegistrationAge(viewModel.dateOfBirth)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Shared Sub-Views

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .tracking(-0.3)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private func nextButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(localized: "ileri"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(enabled ? .black : .black.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? Color.white : Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    // MARK: - Password Strength

    private enum PasswordStrength: Int {
        case weak = 1, fair = 2, good = 3, strong = 4

        var label: String {
            switch self {
            case .weak: return String(localized: "zayıf")
            case .fair: return String(localized: "orta")
            case .good: return String(localized: "iyi")
            case .strong: return String(localized: "güçlü")
            }
        }

        var color: Color {
            switch self {
            case .weak: return .white.opacity(0.25)
            case .fair: return .white.opacity(0.45)
            case .good: return .white.opacity(0.65)
            case .strong: return .white.opacity(0.9)
            }
        }
    }

    private func evaluatePassword(_ password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...1: return .weak
        case 2: return .fair
        case 3...4: return .good
        default: return .strong
        }
    }

    private var passwordStrengthView: some View {
        let strength = evaluatePassword(viewModel.password)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 3)
                    Capsule()
                        .fill(strength.color)
                        .frame(width: geo.size.width * CGFloat(strength.rawValue) / 4.0, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: strength.rawValue)
                }
            }
            .frame(height: 3)

            HStack(spacing: 6) {
                Text(String(localized: "şifre gücü:"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                Text(strength.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(strength.color)
                Spacer()
                if viewModel.password.count < 8 {
                    Text(String(localized: "min. 8 karakter"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }

    // MARK: - Consent Checkbox

    private func consentCheckbox(title: String, isAccepted: Binding<Bool>, document: LegalDocument) -> some View {
        HStack(spacing: 10) {
            Button {
                HapticsManager.playSelection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isAccepted.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isAccepted.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isAccepted.wrappedValue ? .white : .white.opacity(0.25))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAccepted.wrappedValue)
            }

            Button {
                onPresentLegalDocument(document)
            } label: {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .underline()
            }

            Spacer()
        }
    }
}
