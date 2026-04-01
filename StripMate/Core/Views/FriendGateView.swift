import SwiftUI
import FirebaseAuth
import CoreImage.CIFilterBuiltins

// MARK: - Friend Gate View
// Kayıt sonrası zorunlu arkadaş ekleme ekranı.
// İstek gönderildikten veya kod paylaşıldıktan sonra serbest kalır.

public struct FriendGateView: View {
    let onFriendAdded: () -> Void

    @State private var searchCode = ""
    @State private var searchedProfile: UserProfile?
    @State private var pendingRequests: [FriendStatus] = []
    @State private var isSearching = false
    @State private var isLoadingPending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showQR = false
    @State private var myInviteCode: String = ""
    @State private var appeared = false

    private let deps = DependencyContainer.shared

    // Gate'i geçme koşulu: istek gönderildi veya kod paylaşıldı
    private let shareMessage = "anlık.'ta beni ekle! kodum: "

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

                    searchSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

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
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)

                    if !pendingRequests.isEmpty {
                        pendingSection
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if showQR, !myInviteCode.isEmpty {
                qrOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .task {
            await loadMyCode()
            await loadPendingRequests()
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 20) {
            Text("son bir adım kaldı.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-0.3)

            VStack(spacing: 10) {
                Text("anlık. yalnız kullanılan bir uygulama değil. anlarını birisiyle paylaşman için tasarlandı.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Text("aşağıdan arkadaşının kodunu girebilir ya da kendi kodunu paylaşabilirsin. istek gönderdiğin anda uygulamayı kullanmaya başlayabilirsin.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)

            Text("— anlık. ekibi")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 4)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("arkadaşının kodunu gir")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)

            HStack(spacing: 10) {
                TextField("8 haneli kodu gir", text: $searchCode)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
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
                                .font(.system(size: 16, weight: .bold))
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
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName ?? "Kullanıcı")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let username = profile.username {
                        Text("@\(username)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Button {
                    Task { await addFriend(profile.id) }
                } label: {
                    Text("ekle")
                        .font(.system(size: 14, weight: .bold))
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
                Text("veya kendi kodunu paylaş")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                Spacer()
            }

            // Davet kodu
            if !myInviteCode.isEmpty {
                HStack {
                    Text(myInviteCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(2)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = myInviteCode
                        HapticsManager.playNotification(type: .success)
                        showTemporarySuccess("kod kopyalandı")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Paylaşım butonları
            HStack(spacing: 12) {
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
                    label: "Mesaj"
                ) {
                    shareViaMessages()
                }

                // QR Kod
                shareButton(
                    icon: nil,
                    systemFallback: "qrcode",
                    label: "QR Kod"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showQR = true }
                }

                // Diğer
                ShareLink(item: "\(shareMessage)\(myInviteCode)") {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                        Text("Diğer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    // Kod paylaşıldı — gate'i geç
                    passGate()
                })
            }
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Pending Requests

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("gelen istekler")
                    .font(.system(size: 13, weight: .semibold))
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
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.profile?.displayName ?? "Kullanıcı")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let username = request.profile?.username {
                            Text("@\(username)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    Button {
                        Task { await acceptRequest(request) }
                    } label: {
                        Text("kabul et")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - QR Overlay

    private var qrOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showQR = false }
                }

            VStack(spacing: 24) {
                Text("qr kodun")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                if let qrImage = generateQRCode(from: myInviteCode) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                Text(myInviteCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("arkadaşın bu kodu tarasın veya girsin")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))

                Button {
                    HapticsManager.playImpact(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showQR = false }
                } label: {
                    Text("kapat")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Message Label

    private func messageLabel(_ text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.red : Color.green).opacity(0.1))
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
            pendingRequests = try await FriendshipService.shared.fetchPendingIncomingRequests()
        } catch {
            pendingRequests = []
        }
        isLoadingPending = false
    }

    private func search() async {
        guard searchCode.count == 8 else { return }
        isSearching = true
        errorMessage = nil
        searchedProfile = nil
        do {
            HapticsManager.playImpact(style: .light)
            searchedProfile = try await deps.userRepository.searchUser(byCode: searchCode)
        } catch {
            HapticsManager.playNotification(type: .error)
            errorMessage = "kullanıcı bulunamadı."
        }
        isSearching = false
    }

    private func addFriend(_ userId: String) async {
        do {
            try await FriendshipService.shared.sendFriendRequest(to: userId)
            HapticsManager.playNotification(type: .success)
            searchedProfile = nil
            searchCode = ""
            // İstek gönderildi — gate'i geç
            passGate()
        } catch {
            HapticsManager.playNotification(type: .error)
            errorMessage = "istek gönderilemedi."
        }
    }

    private func acceptRequest(_ request: FriendStatus) async {
        guard let requesterId = request.requesterId else { return }
        do {
            try await FriendshipService.shared.acceptFriendRequest(from: requesterId)
            HapticsManager.playNotification(type: .success)
            passGate()
        } catch {
            errorMessage = "kabul edilemedi."
        }
    }

    /// Gate'i geç — istek gönderildi, kabul edildi veya kod paylaşıldı
    private func passGate() {
        withAnimation(.easeInOut(duration: 0.3)) {
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
            // Kod paylaşıldı — gate'i geç
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                passGate()
            }
        } else {
            // WhatsApp yüklü değil — genel paylaşıma yönlendir
            errorMessage = "WhatsApp yüklü değil, diğer seçenekleri kullan."
        }
    }

    private func shareViaMessages() {
        let text = "\(shareMessage)\(myInviteCode)"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encoded)") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                passGate()
            }
        }
    }

    // MARK: - QR Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
