import SwiftUI
import AuthenticationServices
import CryptoKit

public struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var resetError: String?
    @State private var isResetting = false
    
    // Consent state
    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedKVKK = false
    @State private var acceptedEULA = false
    @State private var selectedLegalDoc: LegalDocument?
    @State private var selectedAvatarImage: UIImage?
    @State private var showAvatarPicker = false
    
    private var allConsentsAccepted: Bool {
        acceptedTerms && acceptedPrivacy && acceptedKVKK && acceptedEULA
    }
    
    public init() {}
    
    // MARK: - Shared field style
    
    private let fieldCorner: CGFloat = 12
    private let fieldStroke = Color.white.opacity(0.15)
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // Brand Logotype — typography only, no image
                    VStack(spacing: 8) {
                        Text(Brand.name)
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(-1)
                        
                        Text(String(localized: "anı paylaş"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.3))
                            .tracking(4)
                            .textCase(.uppercase)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "anlık — anı paylaş"))
                    .padding(.top, 80)
                    .padding(.bottom, 16)
                    
                    // Input Form
                    VStack(spacing: 14) {
                        if viewModel.isSignUp {
                            // Avatar picker
                            Button {
                                showAvatarPicker = true
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    if let image = selectedAvatarImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 90, height: 90)
                                            .overlay(
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                    .font(.system(size: 36))
                                                    .foregroundStyle(.white.opacity(0.5))
                                            )
                                    }
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.black)
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(String(localized: "Profil fotoğrafı seç"))
                            
                            if selectedAvatarImage == nil {
                                Text(String(localized: "profil fotoğrafı ekle"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            authTextField(
                                placeholder: "ad soyad",
                                text: $viewModel.displayName,
                                icon: "person",
                                contentType: .name
                            )
                            
                            authTextField(
                                placeholder: "kullanıcı adı",
                                text: $viewModel.username,
                                icon: "at",
                                contentType: .username,
                                autocapitalize: false
                            )
                            
                            DatePicker(String(localized: "doğum tarihi"), selection: $viewModel.dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
                        }
                        
                        authTextField(
                            placeholder: "e-posta",
                            text: $viewModel.email,
                            icon: "envelope",
                            contentType: .emailAddress,
                            keyboardType: .emailAddress,
                            autocapitalize: false
                        )
                        
                        // Real-time email validation
                        if viewModel.isSignUp && !viewModel.email.isEmpty {
                            let email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
                            let isValid = isValidEmail(email)
                            HStack(spacing: 6) {
                                Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isValid ? .green.opacity(0.7) : .white.opacity(0.35))
                                Text(isValid ? String(localized: "geçerli e-posta") : String(localized: "geçersiz e-posta formatı"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isValid ? .green.opacity(0.7) : .white.opacity(0.35))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: isValid)
                        }
                        
                        authSecureField(
                            placeholder: "şifre",
                            text: $viewModel.password,
                            icon: "lock",
                            contentType: viewModel.isSignUp ? .newPassword : .password
                        )
                        
                        // Password strength indicator (signup only)
                        if viewModel.isSignUp && !viewModel.password.isEmpty {
                            passwordStrengthView
                        }
                    }
                    .padding(.horizontal, 28)
                    
                    // ── Consent Checkboxes (signup only) ──
                    if viewModel.isSignUp {
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
                        .padding(.horizontal, 28)
                    }
                    
                    // Forgot Password
                    if !viewModel.isSignUp {
                        Button {
                            resetEmail = viewModel.email
                            showResetPassword = true
                        } label: {
                            Text(String(localized: "şifremi unuttum?"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                    }
                    
                    // Status Messages
                    if viewModel.showSuccessMessage {
                        Text(String(localized: "kayıt başarılı! yönlendiriliyorsun..."))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Primary: Solid white button with black text
                        Button {
                            Task {
                                await viewModel.authenticate()
                                // Upload avatar after successful signup
                                if viewModel.isSignUp, let avatar = selectedAvatarImage, viewModel.errorMessage == nil {
                                    _ = try? await AuthService.shared.uploadAvatar(avatar)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(viewModel.isSignUp ? String(localized: "hesap oluştur") : String(localized: "giriş yap"))
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .foregroundColor(viewModel.isSignUp && (!allConsentsAccepted || selectedAvatarImage == nil) ? .black.opacity(0.4) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.isSignUp && (!allConsentsAccepted || selectedAvatarImage == nil) ? Color.white.opacity(0.3) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(viewModel.isLoading || (viewModel.isSignUp && (!allConsentsAccepted || selectedAvatarImage == nil)))
                        .padding(.horizontal, 28)
                        .accessibilityLabel(viewModel.isSignUp ? String(localized: "hesap oluştur") : String(localized: "giriş yap"))
                        .accessibilityHint(viewModel.isSignUp && !allConsentsAccepted ? String(localized: "yasal belgeleri onaylamalısın") : "")
                        
                        // Consent warning for signup
                        if viewModel.isSignUp && (!allConsentsAccepted || selectedAvatarImage == nil) {
                            Text(selectedAvatarImage == nil ? String(localized: "profil fotoğrafı eklemen gerekiyor") : String(localized: "devam etmek için yasal belgeleri onaylamalısın"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        // Apple Sign In
                        SignInWithAppleButton(.continue) { request in
                            let nonce = viewModel.startAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = viewModel.sha256(nonce)
                        } onCompletion: { result in
                            Task {
                                await viewModel.handleAppleSignIn(result: result)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                        .padding(.horizontal, 28)
                    }
                    
                    // Toggle Sign Up / Sign In
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.isSignUp.toggle()
                            viewModel.errorMessage = nil
                        }
                    } label: {
                        Text(viewModel.isSignUp
                             ? String(localized: "zaten hesabın var mı? giriş yap")
                             : String(localized: "hesabın yok mu? kayıt ol"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPhotoPicker { image in
                selectedAvatarImage = image
            }
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showResetPassword) {
            resetPasswordSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .sheet(item: $selectedLegalDoc) { doc in
            LegalDocumentView(document: doc)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
    }
    
    // MARK: - Reusable Field Components
    
    private func authTextField(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        icon: String,
        contentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocapitalize: Bool = true
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)
            
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
    }
    
    private func authSecureField(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        icon: String,
        contentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)
            
            SecureField(placeholder, text: text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .textContentType(contentType)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
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
            case .weak: return .red.opacity(0.7)
            case .fair: return .orange.opacity(0.7)
            case .good: return .yellow.opacity(0.7)
            case .strong: return .green.opacity(0.7)
            }
        }
    }
    
    private func evaluatePassword(_ password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
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
            // Strength bar
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
            
            // Label + requirements
            HStack(spacing: 6) {
                Text(String(localized: "şifre gücü:"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                Text(strength.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(strength.color)
                Spacer()
                if viewModel.password.count < 6 {
                    Text(String(localized: "min. 6 karakter"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
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
                selectedLegalDoc = document
            } label: {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .underline()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Reset Password Sheet
    
    private var resetPasswordSheet: some View {
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
                
                authTextField(
                    placeholder: "Email",
                    text: $resetEmail,
                    icon: "envelope",
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocapitalize: false
                )
                .padding(.horizontal, 28)
                
                if let message = resetMessage {
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                if let error = resetError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button {
                    Task {
                        guard !resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            resetError = String(localized: "Lütfen e-posta adresini gir")
                            return
                        }
                        isResetting = true
                        resetError = nil
                        resetMessage = nil
                        do {
                            try await DependencyContainer.shared.userRepository.sendPasswordReset(to: resetEmail.trimmingCharacters(in: .whitespacesAndNewlines))
                            resetMessage = String(localized: "Şifre sıfırlama e-postası gönderildi! Gelen kutunu kontrol et.")
                            HapticsManager.playNotification(type: .success)
                        } catch {
                            resetError = String(localized: "Sıfırlama e-postası gönderilemedi.")
                            HapticsManager.playNotification(type: .error)
                        }
                        isResetting = false
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 28)
                .disabled(isResetting)
                
                Spacer()
            }
            .padding(.top, 32)
        }
    }
}
