import SwiftUI

/// Shown after Apple Sign-In when the user's profile is missing required fields
/// (displayName, username, dateOfBirth).
struct ProfileCompletionView: View {
    var onComplete: () -> Void
    
    @State private var displayName = ""
    @State private var username = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAvatarImage: UIImage?
    @State private var showAvatarPicker = false
    @State private var isUploadingAvatar = false

    // Staggered entrance animation
    @State private var appeared = false

    // Consent state
    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedKVKK = false
    @State private var acceptedEULA = false
    
    private var allConsentsAccepted: Bool {
        acceptedTerms && acceptedPrivacy && acceptedKVKK && acceptedEULA
    }
    
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
                        .accessibilityLabel("Profil fotoğrafı seç")
                        
                        if selectedAvatarImage == nil {
                            Text("fotoğraf ekle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        Text("profilini tamamla")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("devam etmek için birkaç bilgiye ihtiyacımız var")
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
                            
                            TextField("", text: $displayName, prompt: Text("ad soyad").foregroundColor(.white.opacity(0.25)))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .textContentType(.name)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
                        .accessibilityLabel("Ad soyad")
                        
                        // Username
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 20)
                            
                            TextField("", text: $username, prompt: Text("kullanıcı adı").foregroundColor(.white.opacity(0.25)))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
                        .accessibilityLabel("Kullanıcı adı")
                        
                        // Date of Birth
                        DatePicker(String(localized: "doğum tarihi"), selection: $dateOfBirth, in: ...(Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous).stroke(fieldStroke, lineWidth: 0.5))
                            .accessibilityLabel("Doğum tarihi")
                    }
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    // Consent Checkboxes
                    VStack(spacing: 10) {
                        consentRow(title: "Kullanım Koşulları", isAccepted: $acceptedTerms)
                        consentRow(title: "Gizlilik Politikası", isAccepted: $acceptedPrivacy)
                        consentRow(title: "KVKK Aydınlatma Metni", isAccepted: $acceptedKVKK)
                        consentRow(title: "EULA", isAccepted: $acceptedEULA)
                        
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
                                Text("tümünü okudum ve kabul ediyorum")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 28)
                    
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
                                Text("devam et")
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
                    
                    if !allConsentsAccepted {
                        Text(selectedAvatarImage == nil ? "profil fotoğrafı eklemen gerekiyor" : "devam etmek için yasal belgeleri onaylamalısın")
                            .font(.system(size: 12, weight: .medium))
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
                }
            }
        }
    }
    
    private var canSave: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedUser.isEmpty && selectedAvatarImage != nil && allConsentsAccepted
    }
    
    private func consentRow(title: String, isAccepted: Binding<Bool>) -> some View {
        Button {
            HapticsManager.playImpact(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAccepted.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isAccepted.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isAccepted.wrappedValue ? .white : .white.opacity(0.3))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
        }
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
        
        let ageComponents = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        if let age = ageComponents.year, age < 13 {
            errorMessage = String(localized: "Kayıt olmak için en az 13 yaşında olmalısın.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Upload avatar — don't block profile save if this fails
                if let avatarImage = selectedAvatarImage {
                    do {
                        _ = try await AuthService.shared.uploadAvatar(avatarImage)
                    } catch {
                        print("DEBUG: Avatar upload failed, continuing with profile save: \(error.localizedDescription)")
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
