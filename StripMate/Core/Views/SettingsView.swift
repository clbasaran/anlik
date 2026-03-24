import SwiftUI
import PhotosUI

// MARK: - Settings View (Comprehensive)

struct SettingsView: View {
    let profile: UserProfile
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var avatarUrl: String?
    @State private var isUploadingAvatar = false
    @State private var showImagePicker = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteConfirmText = ""
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Profile Header
                    profileHeader
                    
                    // MARK: - Sections
                    settingsSection(title: "hesap") {
                        NavigationLink {
                            EditProfileView(profile: profile)
                        } label: {
                            settingsRow(icon: "person.fill", label: "profili düzenle")
                        }
                        
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            settingsRow(icon: "bell.fill", label: "bildirimler")
                        }
                        
                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            settingsRow(icon: "lock.fill", label: "gizlilik")
                        }
                    }
                    
                    settingsSection(title: "uygulama") {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            settingsRow(icon: "paintbrush.fill", label: "görünüm")
                        }
                        
                        NavigationLink {
                            WidgetSettingsView()
                        } label: {
                            settingsRow(icon: "widget.small", label: "widget")
                        }
                        
                        NavigationLink {
                            StorageSettingsView()
                        } label: {
                            settingsRow(icon: "internaldrive.fill", label: "depolama ve veri")
                        }
                    }
                    
                    settingsSection(title: "destek") {
                        NavigationLink {
                            SupportView()
                        } label: {
                            settingsRow(icon: "questionmark.circle.fill", label: "yardım ve destek")
                        }
                        
                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRow(icon: "info.circle.fill", label: "hakkında")
                        }
                    }
                    
                    settingsSection(title: "yasal") {
                        ForEach(LegalDocument.allCases) { doc in
                            NavigationLink {
                                LegalDocumentView(document: doc)
                                    .navigationBarHidden(true)
                            } label: {
                                settingsRow(icon: doc.icon, label: doc.title)
                            }
                        }
                    }
                    
                    settingsSection(title: "hesap yönetimi") {
                        Button {
                            showLogoutAlert = true
                        } label: {
                            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "çıkış yap", isDestructive: false, showChevron: false)
                        }
                        
                        Button {
                            showDeleteAccountAlert = true
                        } label: {
                            settingsRow(icon: "trash.fill", label: "hesabımı sil", isDestructive: true, showChevron: false)
                        }
                    }
                    
                    // Version
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ayarlar")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .alert("çıkış yap", isPresented: $showLogoutAlert) {
            Button("iptal", role: .cancel) {}
            Button("çıkış yap", role: .destructive) {
                dismiss()
                AnalyticsService.shared.log(.logout)
                onLogout()
            }
        } message: {
            Text("hesabından çıkış yapmak istediğine emin misin?")
        }
        .alert("hesabı sil", isPresented: $showDeleteAccountAlert) {
            TextField("onaylamak için \"sil\" yaz", text: $deleteConfirmText)
            Button("iptal", role: .cancel) { deleteConfirmText = "" }
            Button("kalıcı olarak sil", role: .destructive) {
                guard deleteConfirmText.lowercased() == "sil" else { return }
                isDeletingAccount = true
                Task {
                    do {
                        try await DependencyContainer.shared.userRepository.deleteAccount()
                    } catch {
                        HapticsManager.playNotification(type: .error)
                    }
                    isDeletingAccount = false
                    deleteConfirmText = ""
                }
            }
            .disabled(deleteConfirmText.lowercased() != "sil")
        } message: {
            Text("bu işlem geri alınamaz. tüm verileriniz, fotoğraflarınız ve bağlantılarınız kalıcı olarak silinecektir.\n\nonaylamak için \"sil\" yazın.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("hesap siliniyor...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            AvatarPhotoPicker { image in
                isUploadingAvatar = true
                Task {
                    do {
                        let url = try await AuthService.shared.uploadAvatar(image)
                        avatarUrl = url
                        HapticsManager.playNotification(type: .success)
                    } catch {
                        HapticsManager.playNotification(type: .error)
                    }
                    isUploadingAvatar = false
                }
            }
            .presentationBackground(.black)
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    if let url = avatarUrl ?? profile.avatarUrl, let imageUrl = URL(string: url) {
                        CachedAsyncImage(url: imageUrl) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                        } placeholder: {
                            avatarPlaceholder
                        }
                    } else {
                        avatarPlaceholder
                    }
                    
                    if isUploadingAvatar {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 88, height: 88)
                        ProgressView().tint(.white)
                    }
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 30, y: 30)
                }
            }
            .disabled(isUploadingAvatar)
            .accessibilityLabel("Profil fotoğrafı değiştir")
            .accessibilityHint("Galeriden yeni profil fotoğrafı seç")
            
            VStack(spacing: 4) {
                Text(profile.displayName ?? "kullanıcı")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if let username = profile.username {
                    Text("@\(username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Invite Code Pill
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(profile.inviteCode)
                    .font(.system(size: 14, design: .monospaced).weight(.bold))
                    .tracking(2)
            }
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .onTapGesture {
                UIPasteboard.general.string = profile.inviteCode
                HapticsManager.playNotification(type: .success)
            }
            .accessibilityLabel("Davet kodu: \(profile.inviteCode)")
            .accessibilityHint("Kopyalamak için dokun")
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 88, height: 88)
            .overlay(
                Text(String(profile.displayName?.prefix(1) ?? "?"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Section Builder
    
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func settingsRow(icon: String, label: String, isDestructive: Bool = false, showChevron: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDestructive ? .red.opacity(0.7) : .white.opacity(0.5))
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isDestructive ? .red.opacity(0.7) : .white.opacity(0.8))
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
    
    // MARK: - Version Footer
    
    private var versionFooter: some View {
        VStack(spacing: 6) {
            Text("anlık.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.1))
            
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.12))
            }
        }
        .padding(.top, 16)
    }
}
