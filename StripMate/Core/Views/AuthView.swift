import SwiftUI
import AuthenticationServices
import CryptoKit

public struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @AppStorage("show_deleted_account_farewell") private var showDeletedAccountFarewell = false
    @State private var showResetPassword = false
    // Reset-password input + in-flight state moved into AuthResetPasswordSheet,
    // which now owns its own lifecycle. AuthView only opens/dismisses the sheet.

    /// Consent acceptance + signup step + avatar picker now live inside
    /// SignupWizardView. AuthView only owns the legal-document sheet trigger
    /// since it's reusable from elsewhere.
    @State private var selectedLegalDoc: LegalDocument?

    @State private var appeared = false

    public init() {}

    // MARK: - Shared field style
    //
    // Field constants (corner radius, stroke colour, background) live in
    // AuthFieldStyle so login, signup, and reset-password all render the same
    // input look. The reusable inputs themselves are AuthTextField /
    // AuthSecureField in `Auth/AuthFormFields.swift`.

    private let fieldCorner: CGFloat = AuthFieldStyle.cornerRadius

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isSignUp {
                SignupWizardView(
                    viewModel: viewModel,
                    onCancel: {
                        viewModel.isSignUp = false
                    },
                    onPresentLegalDocument: { doc in
                        selectedLegalDoc = doc
                    }
                )
            } else {
                loginView
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .sheet(isPresented: $showResetPassword) {
            AuthResetPasswordSheet()
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

    // MARK: - Login View (unchanged single page)

    private var loginView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                brandHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

                if showDeletedAccountFarewell {
                    deletedAccountFarewellCard
                        .padding(.horizontal, 28)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Email + Password
                VStack(spacing: 14) {
                    AuthTextField(
                        placeholder: "e-posta",
                        text: $viewModel.email,
                        icon: "envelope",
                        contentType: .emailAddress,
                        keyboardType: .emailAddress,
                        autocapitalize: false
                    )

                    AuthSecureField(
                        placeholder: "şifre",
                        text: $viewModel.password,
                        icon: "lock",
                        contentType: .password
                    )
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                // Forgot Password — the sheet owns its own email field.
                Button {
                    HapticsManager.playImpact(style: .light)
                    showResetPassword = true
                } label: {
                    Text(String(localized: "şifremi unuttum?"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .buttonStyle(ScaleButtonStyle())

                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                // Login Button
                VStack(spacing: 16) {
                    Button {
                        HapticsManager.playImpact(style: .medium)
                        Task { await viewModel.authenticate() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text(String(localized: "giriş yap"))
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
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 28)

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
                    .padding(.horizontal, 28)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: appeared)

                // Toggle to signup. SignupWizardView resets its own internal step.
                Button {
                    HapticsManager.playSelection()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.isSignUp = true
                        viewModel.errorMessage = nil
                    }
                } label: {
                    Text(String(localized: "hesabın yok mu? kayıt ol"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Brand Header (kept on AuthView since only login surfaces it now)

    private var brandHeader: some View {
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

            Text(String(localized: "yakın hissettiren şeyler burada kalır"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text(String(localized: "yakınında olamasan da aynı yerde kal"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.32))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "anlık — anı paylaş"))
        .padding(.top, 80)
        .padding(.bottom, 16)
    }

    private var deletedAccountFarewellCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "not düştük"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.38))
                .textCase(.uppercase)
                .tracking(1)

            Text(String(localized: "hesabın silindi,\nkapımız yine açık."))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(String(localized: "burada geçirdiğin zamana teşekkür ederiz. bir gün geri dönmek istersen seni yine aynı sıcaklıkla karşılarız."))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showDeletedAccountFarewell = false
                }
            } label: {
                Text(String(localized: "tamam"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // Reset-password sheet body extracted to AuthResetPasswordSheet.swift.
}
