import SwiftUI

/// Shown after Apple Sign-In when the user's profile is missing required fields
/// (displayName, username, dateOfBirth).
struct ProfileCompletionView: View {
    var onComplete: () -> Void
    
    @State private var displayName = ""
    @State private var username = ""
    @State private var dateOfBirth = AppLimits.recommendedDefaultBirthDate
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAvatarImage: UIImage?
    @State private var existingAvatarURL: URL?
    @State private var showAvatarPicker = false
    @State private var isUploadingAvatar = false
    @State private var usernameError: String?

    // Staggered entrance animation
    @State private var appeared = false

    private let fieldCorner: CGFloat = 12
    private let fieldStroke = Color.white.opacity(0.15)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header + Avatar Picker
                    VStack(spacing: 12) {
                        Button {
                            HapticsManager.playSelection()
                            showAvatarPicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let image = selectedAvatarImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let existingAvatarURL {
                                    CachedAsyncImage(url: existingAvatarURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .font(.system(size: 40))
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                }
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.black)
                                    )
                            }
                        }
                        .accessibilityLabel(String(localized: "Profil fotoğrafı seç"))

                        if selectedAvatarImage == nil && existingAvatarURL == nil {
                            Text(String(localized: "fotoğraf ekle"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Text(String(localized: "profilini tamamla"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "devam etmek için birkaç bilgiye ihtiyacımız var"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

                    // Fields
                    VStack(spacing: 14) {
                        // Display Name
                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 20)

                            TextField("", text: $displayName, prompt: Text(String(localized: "ad soyad")).foregroundColor(.white.opacity(0.25)))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .textContentType(.name)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
                        .accessibilityLabel(String(localized: "Ad soyad"))
                        
                        // Username
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                Image(systemName: "at")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 20)

                                TextField("", text: $username, prompt: Text(String(localized: "kullanıcı adı")).foregroundColor(.white.opacity(0.25)))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: username) { _, newValue in
                                        username = newValue.trimmingCharacters(in: .whitespaces)
                                        usernameError = Self.validateUsername(username)
                                    }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(usernameError != nil && !username.isEmpty ? Color.red.opacity(0.4) : fieldStroke, lineWidth: 0.5))

                            if let usernameError, !username.isEmpty {
                                Text(usernameError)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.leading, 4)
                            }
                        }
                        .accessibilityLabel(String(localized: "Kullanıcı adı"))
                        
                        // Date of Birth
                        DatePicker(
                            String(localized: "doğum tarihi"),
                            selection: $dateOfBirth,
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
                            .accessibilityLabel(String(localized: "Doğum tarihi"))
                    }
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Save Button
                    Button {
                        HapticsManager.playImpact(style: .medium)
                        saveProfile()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text(String(localized: "devam et"))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(!canSave ? .black.opacity(0.4) : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(!canSave ? Color.white.opacity(0.3) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canSave || isLoading)
                    .padding(.horizontal, 28)
                    
                    if selectedAvatarImage == nil && existingAvatarURL == nil {
                        Text(String(localized: "fotoğraf opsiyonel — sonra ayarlardan ekleyebilirsin"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPhotoPicker { image in
                selectedAvatarImage = image
            }
            .presentationBackground(.black)
        }
        .onAppear {
            // Pre-fill displayName if available from Apple
            Task {
                if let profile = await AuthService.shared.currentUserProfile {
                    let name = profile.displayName ?? ""
                    if !name.isEmpty && name != "Apple User" {
                        displayName = name
                    }
                    if let avatar = profile.avatarUrl, let url = URL(string: avatar), !avatar.isEmpty {
                        existingAvatarURL = url
                    }
                }
            }
        }
    }
    
    private var canSave: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avatar is optional — user can add one later from settings/profile.
        return !trimmedName.isEmpty && !trimmedUser.isEmpty && usernameError == nil
    }
    
    /// Returns an error string if the username is invalid, or nil if valid.
    static func validateUsername(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count < AppLimits.usernameMinLength {
            return String(localized: "en az \(AppLimits.usernameMinLength) karakter olmalı")
        }
        if trimmed.count > AppLimits.usernameMaxLength {
            return String(localized: "en fazla \(AppLimits.usernameMaxLength) karakter olabilir")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return String(localized: "yalnızca harf, rakam ve alt cizgi kullanılabilir")
        }
        return nil
    }

    private func saveProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "Lütfen adını gir")
            return
        }
        guard !trimmedUser.isEmpty else {
            errorMessage = String(localized: "Lütfen bir kullanıcı adı seç")
            return
        }
        if let validationError = Self.validateUsername(trimmedUser) {
            errorMessage = validationError
            return
        }
        
        if !AppLimits.meetsMinimumRegistrationAge(dateOfBirth) {
            errorMessage = String(localized: "kayıt için en az \(AppLimits.minimumRegistrationAge) yaşında olmalısın.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Upload avatar before profile save
                if let avatarImage = selectedAvatarImage {
                    do {
                        _ = try await AuthService.shared.uploadAvatar(avatarImage)
                    } catch {
                        errorMessage = String(localized: "Profil fotoğrafı yüklenemedi. Lütfen tekrar dene.")
                        isLoading = false
                        return
                    }
                }

                try await AuthService.shared.completeProfile(
                    displayName: trimmedName,
                    username: trimmedUser,
                    dateOfBirth: dateOfBirth
                )
                HapticsManager.playNotification(type: .success)
                await MainActor.run {
                    onComplete()
                }
            } catch {
                errorMessage = error.localizedDescription
                HapticsManager.playNotification(type: .error)
            }
            isLoading = false
        }
    }
}
