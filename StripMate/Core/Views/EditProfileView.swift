import SwiftUI

// MARK: - Edit Profile View

struct EditProfileView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedDate: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    private let maxBioLength = 60
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Display Name
                fieldSection(title: String(localized: "görünen ad")) {
                    TextField("", text: $displayName, prompt: Text(String(localized: "adın")).foregroundColor(.white.opacity(0.2)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .accessibilityLabel(String(localized: "Görünen ad"))
                        .accessibilityHint(String(localized: "Profilde görünen adını düzenle"))
                }
                
                // Username
                fieldSection(title: String(localized: "kullanıcı adı")) {
                    HStack {
                        Text("@")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("", text: $username, prompt: Text(String(localized: "kullanıcı adı")).foregroundColor(.white.opacity(0.2)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .accessibilityLabel(String(localized: "Kullanıcı adı"))
                    .accessibilityHint(String(localized: "@ ile başlayan benzersiz kullanıcı adını düzenle"))
                }
                
                // Bio
                fieldSection(title: String(localized: "biyografi")) {
                    VStack(alignment: .trailing, spacing: 6) {
                        TextField("", text: $bio, prompt: Text(String(localized: "kendinden kısaca bahset...")).foregroundColor(.white.opacity(0.2)), axis: .vertical)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2...3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > maxBioLength {
                                    bio = String(newValue.prefix(maxBioLength))
                                }
                            }
                        
                        Text("\(bio.count)/\(maxBioLength)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.trailing, 4)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Biyografi, \(bio.count) / \(maxBioLength) karakter"))
                }
                
                // Birthday
                fieldSection(title: String(localized: "doğum tarihi")) {
                    DatePicker("", selection: $selectedDate, in: ...(Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .accessibilityLabel(String(localized: "Doğum tarihi"))
                }
                
                // Email (read-only)
                if let email = profile.email {
                    fieldSection(title: String(localized: "e-posta")) {
                        HStack {
                            Text(email)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                
                // Invite Code (read-only)
                fieldSection(title: String(localized: "davet kodu")) {
                    HStack {
                        Text(profile.inviteCode)
                            .font(.system(size: 16, design: .monospaced).weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = profile.inviteCode
                            HapticsManager.playNotification(type: .success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Save Button
                Button {
                    saveProfile()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        }
                        Text(String(localized: "kaydet"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(String(localized: "profili düzenle"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            displayName = profile.displayName ?? ""
            username = profile.username ?? ""
            bio = profile.bio ?? ""
            selectedDate = profile.dateOfBirth ?? Date()
        }
        .overlay {
            if showSuccess {
                VStack {
                    Text(String(localized: "✓ kaydedildi"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSuccess = false }
                    }
                }
            }
        }
    }
    
    private func fieldSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)
            
            content()
        }
    }
    
    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
                let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
                
                guard !trimmedName.isEmpty else {
                    errorMessage = String(localized: "görünen ad boş olamaz.")
                    isSaving = false
                    return
                }
                
                // Save to Firestore
                try await AuthService.shared.updateProfile(
                    displayName: trimmedName,
                    username: trimmedUsername.isEmpty ? nil : trimmedUsername,
                    bio: trimmedBio.isEmpty ? nil : trimmedBio,
                    dateOfBirth: selectedDate
                )
                
                HapticsManager.playNotification(type: .success)
                withAnimation { showSuccess = true }
            } catch {
                errorMessage = error.localizedDescription
                HapticsManager.playNotification(type: .error)
            }
            isSaving = false
        }
    }
}
