import SwiftUI

/// Sheet shown when a QR code is detected in the camera viewfinder.
/// Resolves the invite code to a user profile and offers an "arkadaş ekle" action.
struct QRFriendAddPopup: View {
    let inviteCode: String
    let onDismiss: () -> Void

    @State private var resolvedProfile: UserProfile?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var requestSent = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Subtle radial glow behind avatar
            if resolvedProfile != nil {
                RadialGradient(
                    colors: [.white.opacity(0.03), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 200
                )
                .offset(y: -40)
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // ── Drag indicator ──
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                Spacer()

                // ── Content ──
                if isLoading {
                    loadingState
                } else if let profile = resolvedProfile {
                    profileCard(for: profile)
                        .scaleEffect(appeared ? 1 : 0.9)
                        .opacity(appeared ? 1 : 0)
                } else {
                    errorCard
                        .scaleEffect(appeared ? 1 : 0.9)
                        .opacity(appeared ? 1 : 0)
                }

                Spacer()

                // ── Bottom: kapat / invite code ──
                VStack(spacing: 12) {
                    // Invite code pill
                    Text(inviteCode)
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.2))
                        .tracking(3)

                    // Kapat button (only if not auto-dismissed)
                    if !requestSent {
                        Button {
                            onDismiss()
                        } label: {
                            Text(String(localized: "kapat"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .task {
            await resolveInviteCode()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            // Pulsing circle placeholder
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 100, height: 100)
                .overlay(
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .scaleEffect(1.2)
                )

            Text(String(localized: "kullanıcı aranıyor…"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Profile Card

    @ViewBuilder
    private func profileCard(for profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            // ── Avatar ──
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 120, height: 120)

                Group {
                    if let url = profile.avatarUrl.flatMap(URL.init) {
                        CachedAsyncImage(url: url) { img in
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            avatarPlaceholder(for: profile)
                        }
                    } else {
                        avatarPlaceholder(for: profile)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 100, height: 100)
                )
            }
            .padding(.bottom, 24)

            // ── Name ──
            HStack(spacing: 6) {
                Text(profile.displayName ?? profile.username ?? String(localized: "bilinmeyen"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                if let emoji = profile.statusEmoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 18))
                }
            }
            .padding(.bottom, 4)

            // ── Username ──
            if let username = profile.username {
                Text("@\(username)")
                    .font(.system(size: 14, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 6)
            }

            // ── Bio ──
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 4)
            }

            // ── Action button ──
            Group {
                if requestSent {
                    // Success state
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text(String(localized: "istek gönderildi"))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Add button
                    Button {
                        sendRequest(to: profile.id)
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.black)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(String(localized: "arkadaş ekle"))
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isSending)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
        }
    }

    // MARK: - Error Card

    private var errorCard: some View {
        VStack(spacing: 24) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 100, height: 100)
                Image(systemName: "person.slash.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.15))
            }

            VStack(spacing: 8) {
                Text(String(localized: "kullanıcı bulunamadı"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text(errorMessage ?? String(localized: "bu qr koda ait bir hesap yok"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }

            Button {
                onDismiss()
            } label: {
                Text(String(localized: "geri dön"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Avatar Placeholder

    private func avatarPlaceholder(for profile: UserProfile) -> some View {
        Circle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(profile.displayName?.prefix(1) ?? "?"))
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            )
    }

    // MARK: - Networking

    private func resolveInviteCode() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await DependencyContainer.shared.userRepository.searchUser(byCode: inviteCode)
            // If we have blocked this user, surface the same "invalid code"
            // message instead of revealing their profile or letting the request
            // through. We deliberately reuse the existing string so the scanner
            // can't tell whether the code was wrong or the user was blocked.
            let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
            if blockedIds.contains(profile.id) {
                self.errorMessage = String(localized: "davet kodu geçersiz")
                return
            }
            self.resolvedProfile = profile
        } catch {
            self.errorMessage = String(localized: "davet kodu geçersiz")
        }
    }

    private func sendRequest(to userId: String) {
        isSending = true
        Task {
            do {
                try await DependencyContainer.shared.friendRepository.sendRequest(to: userId)
                await MainActor.run {
                    withAnimation(Brand.Animations.standard) {
                        requestSent = true
                    }
                    isSending = false
                    HapticsManager.playNotification(type: .success)
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onDismiss()
            } catch {
                await MainActor.run {
                    isSending = false
                    HapticsManager.playNotification(type: .error)
                }
            }
        }
    }
}
