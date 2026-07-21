import SwiftUI
import PhotosUI
import SwiftData
import AuthenticationServices
import CryptoKit
import FirebaseAuth

// MARK: - Settings View (Comprehensive)

struct SettingsView: View {
    let profile: UserProfile
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Cihaza eşitlenmiş an geçmişi — GDPR dışa aktarımında kullanılır.
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]

    @State private var avatarUrl: String?
    @State private var isUploadingAvatar = false
    @State private var showImagePicker = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteConfirmText = ""

    /// Accepts the localized confirmation word ("sil" in Turkish, "delete" in
    /// English, etc.) plus the raw tokens as a safety net, so the typed-word
    /// gate works in every shipped language.
    private var isDeleteConfirmed: Bool {
        let typed = deleteConfirmText.trimmingCharacters(in: .whitespaces).lowercased()
        return typed == String(localized: "sil").lowercased() || typed == "sil" || typed == "delete"
    }
    @State private var deleteAccountError: String?
    @State private var showLogoutAlert = false
    @State private var isExportingData = false
    @State private var showExportShare = false
    @State private var exportFileURL: URL?

    // Re-auth flow: silme requiresRecentLogin ile düşerse kullanıcıyı
    // çıkış/giriş avına göndermek yerine yerinde kimlik doğrulama sunulur.
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthError: String?
    @State private var isReauthenticating = false
    @State private var reauthNonce: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Profile Header
                    profileHeader

                    // MARK: - Sections
                    settingsSection(title: String(localized: "hesap")) {
                        NavigationLink {
                            EditProfileView(profile: profile)
                        } label: {
                            settingsRow(icon: "person.fill", label: String(localized: "profili düzenle"))
                        }

                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            settingsRow(icon: "bell.fill", label: String(localized: "bildirimler"))
                        }

                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            settingsRow(icon: "lock.fill", label: String(localized: "gizlilik"))
                        }

                        NavigationLink {
                            BlockedUsersView()
                        } label: {
                            settingsRow(icon: "nosign", label: String(localized: "engellenen kullanıcılar"))
                        }
                    }

                    settingsSection(title: String(localized: "uygulama")) {
                        NavigationLink {
                            SummariesView()
                        } label: {
                            settingsRow(icon: "chart.bar.fill", label: String(localized: "özetler"))
                        }

                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            settingsRow(icon: "paintbrush.fill", label: String(localized: "görünüm"))
                        }

                        NavigationLink {
                            WidgetSettingsView()
                        } label: {
                            settingsRow(icon: "widget.small", label: "widget")
                        }

                        NavigationLink {
                            StorageSettingsView()
                        } label: {
                            settingsRow(icon: "internaldrive.fill", label: String(localized: "depolama ve veri"))
                        }
                    }

                    settingsSection(title: String(localized: "destek")) {
                        NavigationLink {
                            HelpGuideView()
                        } label: {
                            settingsRow(icon: "book.fill", label: String(localized: "rehber ve destek"))
                        }

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRow(icon: "info.circle.fill", label: String(localized: "hakkında"))
                        }
                    }

                    settingsSection(title: String(localized: "yasal")) {
                        ForEach(LegalDocument.allCases) { doc in
                            NavigationLink {
                                LegalDocumentView(document: doc)
                                    .navigationBarHidden(true)
                            } label: {
                                settingsRow(icon: doc.icon, label: doc.title)
                            }
                        }
                    }

                    settingsSection(title: String(localized: "veri ve gizlilik")) {
                        Button {
                            Task { await exportUserData() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 24)

                                Text(String(localized: "verilerini indir"))
                                    .font(Brand.scaledFont(size: 16, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(.white.opacity(0.8))

                                Spacer()

                                if isExportingData {
                                    ProgressView()
                                        .tint(.white.opacity(0.5))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "verilerini indir"))
                        }
                        .disabled(isExportingData)
                    }

                    settingsSection(title: String(localized: "hesap yönetimi")) {
                        Button {
                            HapticsManager.playImpact(style: .medium)
                            showLogoutAlert = true
                        } label: {
                            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: String(localized: "çıkış yap"), isDestructive: false, showChevron: false)
                        }

                        Button {
                            HapticsManager.playImpact(style: .heavy)
                            showDeleteAccountAlert = true
                        } label: {
                            settingsRow(icon: "trash.fill", label: String(localized: "hesabımı sil"), isDestructive: true, showChevron: false)
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
                    Text(String(localized: "ayarlar"))
                        .font(Brand.scaledFont(size: 17, weight: .bold, relativeTo: .body))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(icon: "xmark", size: 32, iconSize: 13, accessibilityLabel: "kapat") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .alert(String(localized: "çıkış yap"), isPresented: $showLogoutAlert) {
            Button(String(localized: "iptal"), role: .cancel) {}
            Button(String(localized: "çıkış yap"), role: .destructive) {
                dismiss()
                AnalyticsService.shared.log(.logout)
                onLogout()
            }
        } message: {
            Text(String(localized: "hesabından çıkış yapmak istediğine emin misin?"))
        }
        .alert(String(localized: "hesabı sil"), isPresented: $showDeleteAccountAlert) {
            TextField(String(localized: "onaylamak için \"sil\" yaz"), text: $deleteConfirmText)
            Button(String(localized: "iptal"), role: .cancel) { deleteConfirmText = "" }
            Button(String(localized: "kalıcı olarak sil"), role: .destructive) {
                guard isDeleteConfirmed else { return }
                Task { await performAccountDeletion() }
            }
            .disabled(!isDeleteConfirmed)
        } message: {
            Text(String(localized: "bu işlem geri alınamaz. tüm verileriniz, fotoğraflarınız ve bağlantılarınız kalıcı olarak silinecektir.\n\nonaylamak için \"sil\" yazın."))
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text(String(localized: "hesap siliniyor..."))
                            .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .errorAlert(errorMessage: $deleteAccountError)
        .sheet(isPresented: $showReauthSheet, onDismiss: {
            reauthPassword = ""
            reauthError = nil
            reauthNonce = nil
        }) {
            reauthSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
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
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Button {
                HapticsManager.playSelection()
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
                        .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                        .foregroundColor(.black)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 30, y: 30)
                }
            }
            .disabled(isUploadingAvatar)
            .accessibilityLabel(String(localized: "Profil fotoğrafı değiştir"))
            .accessibilityHint(String(localized: "Galeriden yeni profil fotoğrafı seç"))

            VStack(spacing: 4) {
                Text(profile.displayName ?? String(localized: "kullanıcı"))
                    .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                    .foregroundColor(.white)

                if let username = profile.username {
                    Text("@\(username)")
                        .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Invite Code Pill
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
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
            .accessibilityLabel(String(localized: "Davet kodu: \(profile.inviteCode)"))
            .accessibilityHint(String(localized: "Kopyalamak için dokun"))
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
                .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
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
                .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                .foregroundStyle(isDestructive ? Brand.error.opacity(0.85) : .white.opacity(0.5))
                .frame(width: 24)

            Text(label)
                .font(Brand.scaledFont(size: 16, weight: .medium, relativeTo: .body))
                .foregroundStyle(isDestructive ? Brand.error.opacity(0.85) : .white.opacity(0.8))

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
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
                .font(Brand.scaledFont(size: 22, weight: .bold, relativeTo: .title3))
                .foregroundStyle(.white.opacity(0.1))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.12))
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Account Deletion + Re-auth (guven-9)

    /// Silme akışının tek girişi. `requiresRecentLogin` hatasında kullanıcıyı
    /// çıkış yap / tekrar gir kısır döngüsüne göndermek yerine yerinde
    /// yeniden kimlik doğrulama sheet'i açar; doğrulama sonrası silme
    /// otomatik tekrar denenir. Yazılı "sil" kapısı alert'te korunur.
    private func performAccountDeletion() async {
        isDeletingAccount = true
        do {
            try await DependencyContainer.shared.userRepository.deleteAccount()
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                showReauthSheet = true
            } else {
                deleteAccountError = String(localized: "hesap silinemedi. tekrar dene.")
                HapticsManager.playNotification(type: .error)
            }
        }
        isDeletingAccount = false
        deleteConfirmText = ""
    }

    /// Aktif oturumun giriş yöntemleri ("apple.com", "password", ...).
    private var authProviderIds: [String] {
        Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []
    }

    private var reauthSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 28)

            Text(String(localized: "kimliğini doğrula."))
                .font(Brand.scaledFont(size: 22, weight: .semibold, relativeTo: .title3))
                .foregroundColor(.white)

            Text(String(localized: "güvenlik için hesabını silmeden önce kimliğini doğrulaman gerekiyor."))
                .font(Brand.scaledFont(size: 15, weight: .regular, relativeTo: .body))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let reauthError {
                Text(reauthError)
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundColor(Brand.error.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isReauthenticating {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    if authProviderIds.contains("apple.com") {
                        SignInWithAppleButton(.continue) { request in
                            let nonce = Self.randomNonceString()
                            reauthNonce = nonce
                            request.requestedScopes = []
                            request.nonce = nonce.map(Self.sha256)
                        } onCompletion: { result in
                            Task { await handleAppleReauth(result: result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(String(localized: "apple ile kimliğini doğrula"))
                    }

                    if authProviderIds.contains("password") {
                        SecureField(String(localized: "şifren"), text: $reauthPassword)
                            .font(Brand.scaledFont(size: 16, weight: .regular, relativeTo: .body))
                            .foregroundColor(.white)
                            .textContentType(.password)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel(String(localized: "şifren"))

                        Button {
                            HapticsManager.playImpact(style: .medium)
                            Task { await handlePasswordReauth() }
                        } label: {
                            Text(String(localized: "doğrula ve hesabı sil."))
                                .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                                .foregroundColor(Brand.error.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Brand.error.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(reauthPassword.isEmpty)
                        .opacity(reauthPassword.isEmpty ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                showReauthSheet = false
            } label: {
                Text(String(localized: "iptal"))
                    .font(Brand.scaledFont(size: 16, weight: .regular, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private func handleAppleReauth(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = reauthNonce,
                  let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                reauthError = String(localized: "doğrulama başarısız. tekrar dene.")
                HapticsManager.playNotification(type: .error)
                return
            }
            reauthNonce = nil
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: nil
            )
            await reauthenticateAndRetryDeletion(with: credential)
        case .failure(let error):
            // Kullanıcı vazgeçtiyse hata gösterme.
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                reauthError = String(localized: "doğrulama başarısız. tekrar dene.")
                HapticsManager.playNotification(type: .error)
            }
        }
    }

    private func handlePasswordReauth() async {
        guard let email = Auth.auth().currentUser?.email ?? profile.email else {
            reauthError = String(localized: "doğrulama başarısız. tekrar dene.")
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: reauthPassword)
        await reauthenticateAndRetryDeletion(with: credential)
    }

    private func reauthenticateAndRetryDeletion(with credential: AuthCredential) async {
        guard let user = Auth.auth().currentUser else {
            reauthError = String(localized: "doğrulama başarısız. tekrar dene.")
            return
        }
        isReauthenticating = true
        reauthError = nil
        do {
            _ = try await user.reauthenticate(with: credential)
            isReauthenticating = false
            showReauthSheet = false
            reauthPassword = ""
            // Taze oturumla silmeyi otomatik tekrar dene — kullanıcı yazılı
            // "sil" kapısından zaten geçti, ritüeli baştan yaptırma.
            await performAccountDeletion()
        } catch {
            isReauthenticating = false
            reauthError = String(localized: "doğrulama başarısız. tekrar dene.")
            HapticsManager.playNotification(type: .error)
        }
    }

    // MARK: - Nonce Helpers (Apple re-auth)

    private static func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else { return nil }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - GDPR Data Export

    private func exportUserData() async {
        isExportingData = true
        defer { isExportingData = false }

        let deps = DependencyContainer.shared
        let dateFormatter = ISO8601DateFormatter()

        // 1. Profile data
        var exportDict: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "profile": [
                "id": profile.id,
                "email": profile.email ?? "",
                "displayName": profile.displayName ?? "",
                "username": profile.username ?? "",
                "inviteCode": profile.inviteCode,
                "bio": profile.bio ?? "",
                "statusEmoji": profile.statusEmoji ?? "",
                "favoriteSong": profile.favoriteSong ?? "",
                "zodiacSign": profile.zodiacSign ?? "",
                "personalityEmojis": profile.personalityEmojis ?? [],
                "avatarUrl": profile.avatarUrl ?? ""
            ]
        ]

        // 2. Friends list
        do {
            let friends = try await deps.friendRepository.fetchFriends()
            let friendsData: [[String: Any]] = friends.map { friend in
                [
                    "userId": friend.userId,
                    "displayName": friend.profile?.displayName ?? "",
                    "username": friend.profile?.username ?? "",
                    "isPending": friend.isPending
                ]
            }
            exportDict["friends"] = friendsData
        } catch {
            exportDict["friends"] = [] as [Any]
        }

        // 3. Moments (strip history) — kullanıcının asıl verisi bu (guven-10).
        // Cihaza eşitlenmiş SwiftData kopyasından okunur: ağ gerektirmez ve
        // history feed'in Firestore sayfalama imlecine dokunmaz.
        let momentsData: [[String: Any]] = localStrips.map { strip in
            var entry: [String: Any] = [
                "id": strip.id,
                "direction": strip.senderId == profile.id ? "sent" : "received",
                "senderId": strip.senderId,
                "receiverIds": strip.receiverIds,
                "timestamp": dateFormatter.string(from: strip.timestamp),
                "imageUrl": strip.imageUrl,
                "isSecret": strip.isSecret
            ]
            if let city = strip.cityName { entry["cityName"] = city }
            if let thumb = strip.thumbnailUrl { entry["thumbnailUrl"] = thumb }
            if let video = strip.videoUrl {
                entry["videoUrl"] = video
                if let duration = strip.videoDuration { entry["videoDuration"] = duration }
            }
            if let voice = strip.voiceUrl { entry["voiceUrl"] = voice }
            return entry
        }
        exportDict["moments"] = momentsData

        // 4. Conversations — thread summaries + full message texts (capped).
        let maxMessagesPerThread = 500
        do {
            let friends = try await deps.friendRepository.fetchFriends()
            let activeFriends = friends.filter { !$0.isPending }
            var threadsData: [[String: Any]] = []
            for friend in activeFriends {
                // Page backwards from now until the thread is exhausted or the
                // cap is hit — loadMoreMessages returns ascending chunks.
                var messages: [DirectMessage] = []
                var cursor = Date()
                while messages.count < maxMessagesPerThread {
                    let page = await deps.chatRepository.loadMoreMessages(with: friend.userId, before: cursor)
                    guard !page.isEmpty, let oldest = page.first?.timestamp else { break }
                    messages = page + messages
                    cursor = oldest
                }
                if messages.count > maxMessagesPerThread {
                    messages = Array(messages.suffix(maxMessagesPerThread))
                }

                let summary = await ChatService.shared.fetchThreadSummary(partnerId: friend.userId)
                guard summary != nil || !messages.isEmpty else { continue }

                let messagesData: [[String: Any]] = messages.map { message in
                    var entry: [String: Any] = [
                        "senderId": message.senderId,
                        "text": message.isDeleted == true ? "" : message.text,
                        "timestamp": dateFormatter.string(from: message.timestamp)
                    ]
                    if message.isDeleted == true { entry["isDeleted"] = true }
                    if let readAt = message.readAt {
                        entry["readAt"] = dateFormatter.string(from: readAt)
                    }
                    return entry
                }

                var threadEntry: [String: Any] = [
                    "partnerId": friend.userId,
                    "partnerName": friend.profile?.displayName ?? "",
                    "messageCount": messagesData.count,
                    "messages": messagesData
                ]
                if let summary {
                    threadEntry["lastMessage"] = summary.lastMessage
                    threadEntry["lastMessageTimestamp"] = dateFormatter.string(from: summary.lastMessageTimestamp)
                    threadEntry["unreadCount"] = summary.unreadCount
                }
                threadsData.append(threadEntry)
            }
            exportDict["conversations"] = threadsData
        } catch {
            exportDict["conversations"] = [] as [Any]
        }

        // 5. Scope notes — kapsamı dürüstçe belgele (limit + kaynak).
        exportDict["notes"] = [
            String(localized: "anlar: cihazına eşitlenmiş an geçmişini içerir."),
            String(localized: "mesajlar: her sohbet için en fazla son 500 mesaj dahildir.")
        ]

        // 6. Write JSON file
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
            let fileName = "anlik_verilerim_\(profile.username ?? profile.id).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            exportFileURL = tempURL
            showExportShare = true
        } catch {
            // Silent fail — user sees no share sheet
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
