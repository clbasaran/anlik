import SwiftUI
import FirebaseAuth
import CoreImage.CIFilterBuiltins

// MARK: - Friend Gate View
// Kayıt sonrası zorunlu arkadaş ekleme ekranı.
// İstek gönderildikten veya kod paylaşıldıktan sonra serbest kalır.

public struct FriendGateView: View {
    let onFriendAdded: () -> Void

    @AppStorage("hasPassedFriendGate") private var hasPassedFriendGate = false
    @AppStorage("show_friend_gate_warm_note") private var showWarmWelcome = true
    @State private var searchCode = ""
    @State private var searchedProfile: UserProfile?
    @State private var pendingRequests: [FriendStatus] = []
    @State private var isSearching = false
    @State private var isLoadingPending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showQR = false
    @State private var showQRScanner = false
    @State private var showContactSync = false
    @State private var myInviteCode: String = ""
    @State private var appeared = false
    @State private var hasStartedPendingListener = false
    @State private var pendingRequestIds: Set<String> = []
    @State private var highlightedPendingRequestIds: Set<String> = []

    @State private var showHelpSheet = false
    /// Stored observer task so onDisappear has a deterministic cancel point.
    /// SwiftUI's .task already cancels on disappear via the for-await loop, but
    /// holding the task explicitly removes any ambiguity if the view is reused.
    @State private var pendingObserverTask: Task<Void, Never>?

    private let deps = DependencyContainer.shared

    // Gate'i geçme koşulu: istek gönderildi veya kod paylaşıldı
    private let shareMessage = String(localized: "anlık.'ta buluşalım: https://anlik.web.app/i/")

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    if showWarmWelcome {
                        WarmNoteCard(
                            eyebrow: String(localized: "küçük başlangıç"),
                            title: String(localized: "bir kişiyle başla"),
                            message: String(localized: "ilk bağı kur, sonrası doğal gelir."),
                            dismissLabel: String(localized: "tamam"),
                            onDismiss: {
                                withAnimation(Brand.Animations.fade) {
                                    showWarmWelcome = false
                                }
                            }
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -14)
                        .animation(Brand.Animations.smooth, value: appeared)
                    }

                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .animation(Brand.Animations.smooth, value: appeared)

                    searchSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(Brand.Animations.smooth.delay(0.1), value: appeared)

                    if let profile = searchedProfile {
                        foundUserCard(profile)
                    }

                    if let error = errorMessage {
                        messageLabel(error, isError: true)
                    }
                    if let success = successMessage {
                        messageLabel(success, isError: false)
                    }

                    shareSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(Brand.Animations.smooth.delay(0.2), value: appeared)

                    if !pendingRequests.isEmpty {
                        pendingSection
                            .opacity(appeared ? 1 : 0)
                            .animation(Brand.Animations.smooth.delay(0.3), value: appeared)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if showQR, !myInviteCode.isEmpty {
                FriendGateQROverlay(inviteCode: myInviteCode) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showQR = false }
                    // QR gösterildi = kod paylaşıldı; overlay kapanınca gate açılır.
                    passGateAfterShare(method: "qr_shown")
                }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .task {
            await loadMyCode()
            await loadPendingRequests()
        }
        .task {
            guard !hasStartedPendingListener else { return }
            hasStartedPendingListener = true
            // Hold the observer task so onDisappear can cancel deterministically;
            // also lets us re-establish the listener cleanly if the view comes back.
            pendingObserverTask?.cancel()
            pendingObserverTask = Task { await observePendingRequests() }
            await pendingObserverTask?.value
        }
        .sheet(isPresented: $showQRScanner) {
            InviteCodeScannerView { rawCode in
                Task {
                    await handleScannedCode(rawCode)
                }
            }
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showContactSync) {
            ContactSyncView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .onAppear {
            withAnimation { appeared = true }
            AnalyticsService.shared.log(.friendGateShown)
        }
        .onDisappear {
            // Cancel the Firestore stream observer so the upstream listener is
            // removed (continuation.onTermination fires on Task cancel).
            pendingObserverTask?.cancel()
            pendingObserverTask = nil
            // Reset the dedup flag so a re-entry (e.g. coming back from a sheet)
            // can start a fresh listener — the previous one has been torn down.
            hasStartedPendingListener = false
        }
        .sheet(isPresented: $showHelpSheet) {
            FriendGateHelpSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
    }

    // Help sheet body extracted to FriendGateHelpSheet.swift.
    // Use `FriendGateHelpSheet()` directly when presenting.

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 20) {
            Text(String(localized: "birini ekle, içeri geç."))
                .font(Brand.scaledFont(size: 28, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
                .tracking(-0.3)

            Text(String(localized: "arkadaşının kodunu gir ya da kendi kodunu paylaş. istek gittiği anda içeridesin."))
                .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // Contextual help — clarifies "what do I do if I have no friends?"
            Button {
                HapticsManager.playImpact(style: .light)
                AnalyticsService.shared.log(.friendGateHelpOpened)
                showHelpSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    Text(String(localized: "arkadaş bulamıyor musun?"))
                        .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                }
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityHint(String(localized: "arkadaş ekleme yardımı"))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "arkadaşının kodunu gir"))
                .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)

            HStack(spacing: 10) {
                TextField(String(localized: "8 haneli kodu gir"), text: $searchCode)
                    .font(Brand.scaledFont(size: 16, weight: .medium, design: .monospaced, relativeTo: .body))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: searchCode) { _, newValue in
                        searchCode = String(newValue.prefix(8)).uppercased()
                    }

                Button {
                    Task { await search() }
                } label: {
                    Group {
                        if isSearching {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(width: 50, height: 50)
                    .background(searchCode.count == 8 ? Color.white : Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(searchCode.count != 8 || isSearching)
            }
        }
    }

    // MARK: - Found User Card

    private func foundUserCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                if let urlStr = profile.avatarUrl, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(String(profile.displayName?.prefix(1) ?? "?").uppercased())
                                .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName ?? String(localized: "kullanıcı"))
                        .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.white)
                    if let username = profile.username {
                        Text("@\(username)")
                            .font(Brand.scaledFont(size: 13, relativeTo: .footnote))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Button {
                    Task { await addFriend(profile.id) }
                } label: {
                    Text(String(localized: "ekle"))
                        .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Share Section

    private var shareSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "veya kendi kodunu paylaş"))
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                Spacer()
            }

            // Davet kodu
            if !myInviteCode.isEmpty {
                HStack {
                    Text(myInviteCode)
                        .font(Brand.scaledFont(size: 22, weight: .bold, design: .monospaced, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .tracking(2)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = myInviteCode
                        passGateAfterShare(method: "copy")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Paylaşım butonları
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                // WhatsApp
                shareButton(
                    icon: "whatsapp_icon",
                    systemFallback: "bubble.left.fill",
                    label: "WhatsApp"
                ) {
                    shareViaWhatsApp()
                }

                // iMessage
                shareButton(
                    icon: nil,
                    systemFallback: "message.fill",
                    label: String(localized: "mesaj")
                ) {
                    shareViaMessages()
                }

                // QR Kodum
                shareButton(
                    icon: nil,
                    systemFallback: "qrcode",
                    label: String(localized: "qr kodum")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showQR = true
                    }
                }

                // QR Okut
                shareButton(
                    icon: nil,
                    systemFallback: "viewfinder",
                    label: String(localized: "qr okut")
                ) {
                    showQRScanner = true
                }

                // Rehberden Bul
                shareButton(
                    icon: nil,
                    systemFallback: "person.crop.rectangle.stack",
                    label: String(localized: "rehberden bul")
                ) {
                    showContactSync = true
                }

                // Diğer
                shareButton(
                    icon: nil,
                    systemFallback: "square.and.arrow.up",
                    label: String(localized: "diğer")
                ) {
                    presentSystemShareSheet()
                }
            }
            .padding(.top, 4)

            // Solo keşif — baştan görünür sessiz üçüncül çıkış; kimsesi olmayan
            // kullanıcı iki dakika beklemeden yolunu bulabilsin.
            Button {
                HapticsManager.playImpact(style: .light)
                AnalyticsService.shared.log(.friendGateSkipped)
                AnalyticsService.shared.log(.friendGatePassed, parameters: ["method": "skip"])
                passGate()
            } label: {
                Text(String(localized: "şimdilik solo keşfet →"))
                    .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.vertical, 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(String(localized: "Arkadaş eklemeden devam et"))
            .padding(.top, 4)
        }
    }

    private func shareButton(icon: String?, systemFallback: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsManager.playImpact(style: .light)
            action()
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let iconName = icon, UIImage(named: iconName) != nil {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: systemFallback)
                            .font(Brand.scaledFont(size: 20, weight: .semibold, relativeTo: .title3))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

                Text(label)
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Pending Requests

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "gelen istekler"))
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                Spacer()
                if isLoadingPending {
                    ProgressView().tint(.white.opacity(0.3))
                }
            }

            ForEach(pendingRequests, id: \.userId) { request in
                HStack(spacing: 12) {
                    if let urlStr = request.profile?.avatarUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(String(request.profile?.displayName?.prefix(1) ?? "?").uppercased())
                                    .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.profile?.displayName ?? String(localized: "kullanıcı"))
                            .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.white)
                        if let username = request.profile?.username {
                            Text("@\(username)")
                                .font(Brand.scaledFont(size: 12, relativeTo: .caption))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    Button {
                        Task { await acceptRequest(request) }
                    } label: {
                        Text(String(localized: "kabul et"))
                            .font(Brand.scaledFont(size: 13, weight: .bold, relativeTo: .footnote))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(
                    highlightedPendingRequestIds.contains(request.userId)
                    ? Color.white.opacity(0.14)
                    : Color.white.opacity(0.06)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            highlightedPendingRequestIds.contains(request.userId)
                            ? Color.white.opacity(0.22)
                            : Color.clear,
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .scaleEffect(highlightedPendingRequestIds.contains(request.userId) ? 1.015 : 1)
                .animation(Brand.Animations.standard, value: highlightedPendingRequestIds)
            }
        }
    }

    // QR overlay extracted to FriendGateQROverlay.swift.

    // MARK: - Message Label

    private func messageLabel(_ text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .white.opacity(0.4) : .white.opacity(0.7))
            Text(text)
                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? Color.white.opacity(0.08) : Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func loadMyCode() async {
        if let profile = await deps.userRepository.currentUserProfile {
            myInviteCode = profile.inviteCode
        }
    }

    private func loadPendingRequests() async {
        isLoadingPending = true
        do {
            let requests = try await FriendshipService.shared.fetchPendingIncomingRequests()
            pendingRequests = requests
            pendingRequestIds = Set(requests.map(\.userId))
        } catch {
            pendingRequests = []
            pendingRequestIds = []
        }
        isLoadingPending = false
    }

    private func observePendingRequests() async {
        do {
            let stream = await FriendshipService.shared.listenToPendingIncomingRequests()
            for try await requests in stream {
                if Task.isCancelled { break }
                await MainActor.run {
                    let nextIds = Set(requests.map(\.userId))
                    let newIds = nextIds.subtracting(pendingRequestIds)
                    pendingRequests = requests
                    pendingRequestIds = nextIds
                    isLoadingPending = false

                    if !newIds.isEmpty {
                        HapticsManager.playImpact(style: .light)
                        withAnimation(Brand.Animations.standard) {
                            highlightedPendingRequestIds.formUnion(newIds)
                        }

                        Task {
                            try? await Task.sleep(for: .milliseconds(1800))
                            await MainActor.run {
                                withAnimation(Brand.Animations.fadeOutStandard) {
                                    highlightedPendingRequestIds.subtract(newIds)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoadingPending = false
            }
        }
    }

    private func search() async {
        guard searchCode.count == 8 else { return }
        isSearching = true
        errorMessage = nil
        searchedProfile = nil
        do {
            HapticsManager.playImpact(style: .light)
            let profile = try await deps.userRepository.searchUser(byCode: searchCode)
            let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
            if blockedIds.contains(profile.id) {
                // Block check: act like the code resolved to nothing.
                HapticsManager.playNotification(type: .error)
                errorMessage = String(localized: "bu kodla kimseyi bulamadık.")
            } else {
                searchedProfile = profile
            }
        } catch {
            HapticsManager.playNotification(type: .error)
            errorMessage = String(localized: "bu kodla kimseyi bulamadık.")
        }
        isSearching = false
    }

    private func addFriend(_ userId: String) async {
        do {
            try await FriendshipService.shared.sendFriendRequest(to: userId)
            await MainActor.run {
                HapticsManager.playNotification(type: .success)
                searchedProfile = nil
                searchCode = ""
                showTemporarySuccess(String(localized: "istek gitti. şimdi sıra ilk anda."))
                AnalyticsService.shared.logOnce(.firstFriendAdded)
                AnalyticsService.shared.log(.friendGatePassed, parameters: ["method": "request_sent"])
            }
            // İstek gönderildi — gate'i geç
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                passGate()
            }
        } catch {
            await MainActor.run {
                HapticsManager.playNotification(type: .error)
                errorMessage = String(localized: "istek şu an gitmedi. birazdan tekrar dene.")
            }
        }
    }

    private func handleScannedCode(_ rawCode: String) async {
        guard let code = normalizedInviteCode(from: rawCode) else {
            errorMessage = String(localized: "bu qr kodu okuyamadık.")
            return
        }

        isSearching = true
        errorMessage = nil
        successMessage = nil

        do {
            let profile = try await deps.userRepository.searchUser(byCode: code)
            // Block check: silently fail (use the same QR-couldn't-read string)
            // so a scanned blocked user can't slip through the QR shortcut.
            let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
            if blockedIds.contains(profile.id) {
                await MainActor.run {
                    HapticsManager.playNotification(type: .error)
                    errorMessage = String(localized: "bu qr kodu okuyamadık.")
                    isSearching = false
                }
                return
            }
            try await FriendshipService.shared.sendFriendRequest(to: profile.id)
            await MainActor.run {
                HapticsManager.playNotification(type: .success)
                showTemporarySuccess(String(localized: "istek gitti. şimdi içeridesin."))
                AnalyticsService.shared.logOnce(.firstFriendAdded)
                AnalyticsService.shared.log(.friendGatePassed, parameters: ["method": "qr"])
            }
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                passGate()
            }
        } catch {
            await MainActor.run {
                HapticsManager.playNotification(type: .error)
                errorMessage = String(localized: "qr kod tamam ama istek şu an gitmedi. tekrar deneyelim.")
            }
        }

        isSearching = false
    }

    private func normalizedInviteCode(from rawCode: String) -> String? {
        let uppercase = rawCode.uppercased()
        let characters = uppercase.filter { $0.isLetter || $0.isNumber }
        guard characters.count >= 8 else { return nil }
        return String(characters.suffix(8))
    }

    private func acceptRequest(_ request: FriendStatus) async {
        guard let requesterId = request.requesterId else { return }
        do {
            try await FriendshipService.shared.acceptFriendRequest(from: requesterId)
            await MainActor.run {
                HapticsManager.playNotification(type: .success)
                showTemporarySuccess(String(localized: "artık bağlısınız. ilk anı sen gönder."))
                AnalyticsService.shared.logOnce(.firstFriendAdded)
                AnalyticsService.shared.log(.friendGatePassed, parameters: ["method": "accepted"])
                // First friend connected — good moment to ask for push permission.
                NotificationPermissionPrompter.requestIfUndetermined()
            }
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                passGate()
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "isteği şu an kabul edemedik. tekrar deneyelim.")
            }
        }
    }

    /// Kod paylaşıldı — kullanıcıyı içeri al. Başlıktaki "istek gittiği anda
    /// içeridesin" sözünü paylaşım için de tutar: WhatsApp, mesaj, kopyala,
    /// QR gösterimi ve sistem paylaşımı hepsi gate'i açar.
    private func passGateAfterShare(method: String) {
        guard !hasPassedFriendGate else { return }
        HapticsManager.playNotification(type: .success)
        showTemporarySuccess(String(localized: "kodun yolda — arkadaşın kabul edince ilk anını gönderirsin."))
        AnalyticsService.shared.log(.friendGatePassed, parameters: ["method": "share_\(method)"])
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            passGate()
        }
    }

    /// Gate'i geç — istek gönderildi, kabul edildi veya kod paylaşıldı
    private func passGate() {
        guard !hasPassedFriendGate else {
            onFriendAdded()
            return
        }

        hasPassedFriendGate = true
        withAnimation(Brand.Animations.fadeSlow) {
            onFriendAdded()
        }
    }

    private func showTemporarySuccess(_ message: String) {
        successMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            successMessage = nil
        }
    }

    // MARK: - Share Actions

    private func shareViaWhatsApp() {
        let text = "\(shareMessage)\(myInviteCode)"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "whatsapp://send?text=\(encoded)") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            passGateAfterShare(method: "whatsapp")
        } else {
            errorMessage = String(localized: "whatsapp burada görünmüyor. istersen diğer paylaşım yollarını kullan.")
        }
    }

    private func shareViaMessages() {
        let text = "\(shareMessage)\(myInviteCode)"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encoded)") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            passGateAfterShare(method: "sms")
        }
    }

    /// "diğer" — sistem paylaşım sayfası. Paylaşım tamamlanınca gate açılır;
    /// vazgeçilirse kullanıcı ekranda kalır.
    private func presentSystemShareSheet() {
        let text = "\(shareMessage)\(myInviteCode)"
        let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activityController.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in
                passGateAfterShare(method: "sheet")
            }
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityController, animated: true)
        }
    }

    // MARK: - QR Generation

    // QR generator moved to FriendGateQROverlay.generateQRCode (static).
    // Reuse from any caller that needs a UIImage from an invite code.
}
