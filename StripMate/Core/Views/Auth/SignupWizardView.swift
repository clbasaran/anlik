import SwiftUI
import AuthenticationServices
import FirebaseFirestore

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

    // Debounced username availability — nil means unknown (empty, invalid
    // format, still typing, or the lookup couldn't run). Only a definitive
    // "taken" blocks the next step; the server re-validates at signup anyway.
    @State private var usernameAvailable: Bool? = nil
    @State private var usernameCheckTask: Task<Void, Never>?

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
                withAnimation(Brand.Animations.fadeStandard) {
                    viewModel.errorMessage = nil
                    signupStep = 0
                    onCancel()
                }
            } label: {
                Text(String(localized: "zaten hesabın var mı? giriş yap"))
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Color.white.opacity(0.45))
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
                    withAnimation(Brand.Animations.soft) {
                        signupStep -= 1
                    }
                } else {
                    withAnimation(Brand.Animations.fadeStandard) {
                        viewModel.errorMessage = nil
                        onCancel()
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
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
                        .animation(Brand.Animations.tap, value: signupStep)
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
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(isValid ? .white.opacity(0.7) : .white.opacity(0.35))
                        Text(isValid ? String(localized: "geçerli e-posta") : String(localized: "geçersiz e-posta formatı"))
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(isValid ? .white.opacity(0.7) : .white.opacity(0.35))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                    .animation(Brand.Animations.fadeQuick, value: isValid)
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
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            nextButton(
                enabled: canAdvanceStep0,
                action: {
                    HapticsManager.playImpact(style: .medium)
                    AnalyticsService.shared.log(.signupStepCompleted, parameters: ["step": 0])
                    withAnimation(Brand.Animations.soft) {
                        signupStep = 1
                    }
                }
            )

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                Text(String(localized: "veya"))
                    .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.3))
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
                                    .font(Brand.scaledFont(size: 22, relativeTo: .title3))
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: selectedAvatarImage == nil ? "plus" : "pencil")
                                .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                                .foregroundStyle(.black)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(String(localized: "Profil fotoğrafı ekle (opsiyonel)"))

            if selectedAvatarImage == nil {
                Text(String(localized: "profil fotoğrafı opsiyonel — sonra da ekleyebilirsin"))
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.35))
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
                .onChange(of: viewModel.username) { _, newValue in
                    scheduleUsernameAvailabilityCheck(for: newValue)
                }

                if let available = usernameAvailable,
                   !viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(available ? .white.opacity(0.7) : Brand.error)
                        Text(available
                             ? String(localized: "kullanıcı adı uygun.")
                             : String(localized: "bu kullanıcı adı alınmış."))
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(available ? .white.opacity(0.7) : Brand.error)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                    .animation(Brand.Animations.fadeQuick, value: available)
                }

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
                    withAnimation(Brand.Animations.soft) {
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

            // Two boxes instead of four: the legal trio (terms + privacy + eula)
            // reads as one acceptance — the old select-all proved users treat it
            // that way — while the KVKK acknowledgment stays its own explicit
            // tick, as Turkish data-protection practice expects.
            VStack(spacing: 10) {
                combinedLegalCheckbox

                consentCheckbox(
                    title: String(localized: "KVKK Aydınlatma Metni"),
                    isAccepted: $acceptedKVKK,
                    document: .kvkk
                )
            }

            // Status Messages
            if viewModel.showSuccessMessage {
                Text(String(localized: "kayıt başarılı! yönlendiriliyorsun..."))
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.7))
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
                            .font(Brand.scaledFont(size: 17, weight: .semibold, relativeTo: .body))
                    }
                }
                .foregroundStyle(allConsentsAccepted ? .black : .black.opacity(0.4))
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
        usernameAvailable != false &&
        AppLimits.meetsMinimumRegistrationAge(viewModel.dateOfBirth)
    }

    // MARK: - Username Availability

    /// Debounced pre-flight lookup against the `usernames/{lowercased}`
    /// reservation collection (the same source `validateUsernameUniqueness`
    /// checks at signup), so a taken username surfaces while typing instead
    /// of failing on the final "hesap oluştur" tap after all the consents.
    private func scheduleUsernameAvailabilityCheck(for newValue: String) {
        usernameCheckTask?.cancel()
        usernameAvailable = nil
        let candidate = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Reuse the shared local rules so we never query obviously invalid input.
        guard !candidate.isEmpty,
              EditProfileView.validateUsername(candidate) == nil else { return }
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            let isFree = await Self.lookUpUsernameAvailability(candidate)
            if Task.isCancelled { return }
            // Ignore stale responses if the user kept typing.
            guard viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == candidate else { return }
            withAnimation(Brand.Animations.fadeQuick) { usernameAvailable = isFree }
        }
    }

    /// Returns true when free, false when taken, nil when the lookup could
    /// not run (offline, or no auth session yet — the rules gate reads).
    /// Unknown stays silent and never blocks; `completeEmailSignUp` still
    /// validates uniqueness server-side as the backstop.
    private static func lookUpUsernameAvailability(_ candidate: String) async -> Bool? {
        do {
            let doc = try await Firestore.firestore()
                .collection("usernames").document(candidate)
                .getDocument()
            return !doc.exists
        } catch {
            return nil
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Shared Sub-Views

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Brand.scaledFont(size: 28, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
                .tracking(-0.3)

            Text(subtitle)
                .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private func nextButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(localized: "ileri"))
                .font(Brand.scaledFont(size: 17, weight: .semibold, relativeTo: .body))
                .foregroundStyle(enabled ? .black : .black.opacity(0.4))
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
                        .animation(Brand.Animations.fadeSlow, value: strength.rawValue)
                }
            }
            .frame(height: 3)

            HStack(spacing: 6) {
                Text(String(localized: "şifre gücü:"))
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.35))
                Text(strength.label)
                    .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(strength.color)
                Spacer()
                if viewModel.password.count < 8 {
                    Text(String(localized: "min. 8 karakter"))
                        .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }

    // MARK: - Consent Checkbox

    /// One checkbox for the legal trio; the three documents remain individually
    /// readable via the link row underneath. Toggling writes all three flags so
    /// the persisted consent model is unchanged.
    private var combinedLegalCheckbox: some View {
        let allLegal = acceptedTerms && acceptedPrivacy && acceptedEULA
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    HapticsManager.playSelection()
                    let newVal = !allLegal
                    withAnimation(Brand.Animations.tap) {
                        acceptedTerms = newVal
                        acceptedPrivacy = newVal
                        acceptedEULA = newVal
                    }
                } label: {
                    Image(systemName: allLegal ? "checkmark.square.fill" : "square")
                        .font(Brand.scaledFont(size: 18, weight: .medium, relativeTo: .title3))
                        .foregroundStyle(allLegal ? .white : .white.opacity(0.25))
                        .animation(Brand.Animations.tap, value: allLegal)
                }

                Text(String(localized: "kullanım koşullarını, gizlilik politikasını ve eula'yı okudum, kabul ediyorum."))
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                legalDocLink(String(localized: "koşullar"), .termsOfService)
                legalDocLink(String(localized: "gizlilik"), .privacyPolicy)
                legalDocLink(String(localized: "eula"), .eula)
            }
            .padding(.leading, 28)
        }
        .accessibilityElement(children: .contain)
    }

    private func legalDocLink(_ title: String, _ document: LegalDocument) -> some View {
        Button {
            onPresentLegalDocument(document)
        } label: {
            Text(title)
                .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.4))
                .underline()
        }
    }

    private func consentCheckbox(title: String, isAccepted: Binding<Bool>, document: LegalDocument) -> some View {
        HStack(spacing: 10) {
            Button {
                HapticsManager.playSelection()
                withAnimation(Brand.Animations.tap) {
                    isAccepted.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isAccepted.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(Brand.scaledFont(size: 18, weight: .medium, relativeTo: .title3))
                    .foregroundStyle(isAccepted.wrappedValue ? .white : .white.opacity(0.25))
                    .animation(Brand.Animations.tap, value: isAccepted.wrappedValue)
            }

            Button {
                onPresentLegalDocument(document)
            } label: {
                Text(title)
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.6))
                    .underline()
            }

            Spacer()
        }
    }
}
