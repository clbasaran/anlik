import SwiftUI
import MapKit

// MARK: - History Search Bar

struct HistorySearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.35))

            TextField("", text: $searchText, prompt: Text("ara... \u{015F}ehir, arkada\u{015F} veya tarih")
                .foregroundStyle(.white.opacity(0.3))
            )
            .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - History Header

struct HistoryHeaderView: View {
    let unreadCount: Int
    @Binding var isMapView: Bool
    let onNotificationsTap: () -> Void
    let onCalendarTap: () -> Void
    let onDeleteTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("anlık.")
                .font(Brand.scaledFont(size: 22, weight: .black, relativeTo: .title3))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            ZStack {
                // Center: View toggle pill — always centered
                HStack(spacing: 0) {
                    HistoryToggleButton(title: String(localized: "akış"), icon: "square.grid.2x2", isActive: !isMapView) {
                        isMapView = false
                    }
                    HistoryToggleButton(title: String(localized: "harita"), icon: "map", isActive: isMapView) {
                        isMapView = true
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // Left: notification + calendar
                HStack(spacing: 8) {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        onNotificationsTap()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())

                            if unreadCount > 0 {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 1, y: -1)
                            }
                        }
                    }
                    .accessibilityLabel(String(localized: "bildirimler"))
                    .accessibilityHint(unreadCount > 0 ? String(localized: "\(unreadCount) okunmamış bildirim") : String(localized: "bildirim yok"))

                    Button {
                        HapticsManager.playImpact(style: .light)
                        onCalendarTap()
                    } label: {
                        Image(systemName: "calendar")
                            .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "günlük kapsül"))

                    Spacer()
                }

                // Right: delete button
                HStack {
                    Spacer()

                    Button {
                        HapticsManager.playImpact(style: .medium)
                        onDeleteTap()
                    } label: {
                        Image(systemName: "trash")
                            .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "geçmişi temizle"))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Toggle Button

struct HistoryToggleButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsManager.playSelection()
            withAnimation(Brand.Animations.fadeQuick) { action() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                Text(title)
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
            }
            .foregroundStyle(isActive ? .black : .white.opacity(0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Color.white : Color.clear)
            .clipShape(Capsule())
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Offline Banner

struct HistoryOfflineBanner: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
            Text(String(localized: "bağlantı yok"))
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))

            Button {
                HapticsManager.playImpact(style: .light)
                onRetry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(Brand.scaledFont(size: 10, weight: .bold, relativeTo: .caption))
                    Text(String(localized: "yenile"))
                        .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Secret Locked Explainer

/// Small monochrome sheet shown when the user taps a locked secret strip.
/// Replaces the old silent jump to the camera tab: states the unlock rule
/// as an invitation and offers the camera as the single action
/// (duygusal-8 / guven-8).
struct SecretLockedExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                // Blurred glow behind the lock — same treatment as the
                // SecretUnlockAnimation lock icon, at explainer scale.
                ZStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white.opacity(0.15))
                        .blur(radius: 14)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 34)
                .accessibilityHidden(true)

                Text(String(localized: "gizli an"))
                    .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(.white)

                Text(String(localized: "bir an paylaş, kilit açılsın."))
                    .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer(minLength: 0)

                Button {
                    HapticsManager.playImpact(style: .medium)
                    TabBarState.shared.selectedTab = .camera
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                        Text(String(localized: "kamerayı aç"))
                            .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .accessibilityHint(String(localized: "kamera sekmesine geçer"))
            }
        }
        // .medium stays available so large Dynamic Type sizes can expand
        // instead of clipping inside the fixed-height detent.
        .presentationDetents([.height(310), .medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
    }
}

// MARK: - Feed Card

struct HistoryFeedCard: View {
    let strip: Strip
    let isSentByMe: Bool
    let locked: Bool
    let senderAvatarUrl: String?
    /// Sender-side seen state: non-nil flips the "gönderildi" label to a
    /// "görüldü" variant once at least one receiver opened the strip.
    let seenLabel: String?
    /// Receiver-side unseen state: true shows a white dot on the card until
    /// the current user opens the strip.
    let showUnseenDot: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onSenderAvatarLoad: () -> Void

    @State private var showLockedExplainer = false

    var body: some View {
        let dataSaver = UserDefaults.standard.bool(forKey: "data_saver_mode")
        let feedUrl = URL(string: dataSaver ? (strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl) : (strip.thumbnailUrl ?? strip.imageUrl))

        ZStack {
            // Image — always rendered as a fallback / loading frame. When the
            // strip is a video, the player overlays on top once it's ready.
            CachedAsyncImage(url: feedUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .blur(radius: locked ? 30 : 0)
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 400)
                    .overlay {
                        ProgressView().tint(.white.opacity(0.2))
                    }
            }

            // Inline video playback for video strips. Muted, looping, no tap
            // (the parent card tap opens the detail). The thumbnail above
            // stays as a poster frame until the player is ready, so the
            // transition is invisible.
            if !locked, let videoUrlStr = strip.videoUrl, let videoUrl = URL(string: videoUrlStr) {
                VideoPlayerView(
                    url: videoUrl,
                    startMuted: true,
                    interactive: false,
                    suppressLoadingIndicator: true
                )
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .clipped()
                .blur(radius: locked ? 30 : 0)
            }

            if locked {
                Color.black.opacity(0.5)
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(localized: "gizli an"))
                        .font(Brand.scaledFont(size: 18, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(String(localized: "bu anı görmek için sen de bir an paylaş"))
                        .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Spacer()

                    HStack(spacing: 8) {
                        HistorySenderAvatar(avatarUrl: senderAvatarUrl, onLoad: onSenderAvatarLoad)
                        Text(strip.timestamp, style: .relative)
                            .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            } else {
                VStack {
                    if strip.isSecret && isSentByMe {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(Brand.scaledFont(size: 9, relativeTo: .caption))
                                Text(String(localized: "gizli"))
                                    .font(Brand.scaledFont(size: 10, weight: .bold, relativeTo: .caption))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.trailing, 12)
                            .padding(.top, 12)
                        }
                    }

                    Spacer()

                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.7), location: 0.8),
                                .init(color: .black, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)

                        HStack(alignment: .bottom) {
                            if !isSentByMe {
                                HistorySenderAvatar(avatarUrl: senderAvatarUrl, onLoad: onSenderAvatarLoad)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    if isSentByMe, let seenLabel {
                                        Image(systemName: "eye.fill")
                                            .font(Brand.scaledFont(size: 9, weight: .bold, relativeTo: .caption))
                                        Text(seenLabel)
                                            .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                                            .lineLimit(1)
                                    } else {
                                        Image(systemName: isSentByMe ? "arrow.up.right" : "arrow.down.left")
                                            .font(Brand.scaledFont(size: 9, weight: .bold, relativeTo: .caption))
                                        Text(isSentByMe ? String(localized: "gönderildi") : String(localized: "alındı"))
                                            .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                                    }
                                }
                                .foregroundStyle(.white.opacity(isSentByMe && seenLabel != nil ? 0.7 : 0.5))

                                HStack(spacing: 4) {
                                    if let city = strip.cityName {
                                        Text(city)
                                            .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                                            .foregroundStyle(.white)
                                    }
                                    Text(strip.timestamp, style: .relative)
                                        .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }

                            Spacer()

                            Image(systemName: "bubble.left.fill")
                                .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if showUnseenDot {
                HistoryUnseenDot()
                    .padding(12)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if locked {
                // Locked secret: explain the unlock rule first instead of
                // silently teleporting to the camera — the sheet offers the
                // camera as its single action (duygusal-8).
                HapticsManager.playImpact(style: .light)
                showLockedExplainer = true
            } else {
                onTap()
            }
        }
        .sheet(isPresented: $showLockedExplainer) {
            SecretLockedExplainerSheet()
        }
        .contextMenu {
            if isSentByMe {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(String(localized: "bu anı sil"), systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    onReport()
                } label: {
                    Label(String(localized: "fotoğrafı bildir"), systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}

// MARK: - Grid Card

struct HistoryGridCard: View {
    let strip: Strip
    let locked: Bool
    /// True shows a white dot until the current user (as receiver) opens the strip.
    let showUnseenDot: Bool
    let onTap: () -> Void
    let onReport: (() -> Void)?

    @State private var showLockedExplainer = false

    var body: some View {
        let feedUrl = URL(string: strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl)

        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: feedUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 180, maxHeight: 180)
                    .clipped()
                    .blur(radius: locked ? 20 : 0)
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 180)
            }

            // Inline video playback for grid cards. Same treatment as the feed
            // card — muted loop, parent owns the tap.
            if !locked, let videoUrlStr = strip.videoUrl, let videoUrl = URL(string: videoUrlStr) {
                VideoPlayerView(
                    url: videoUrl,
                    startMuted: true,
                    interactive: false,
                    suppressLoadingIndicator: true
                )
                .frame(minHeight: 180, maxHeight: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .blur(radius: locked ? 20 : 0)
            }

            if locked {
                Color.black.opacity(0.4)
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(Brand.scaledFont(size: 22, relativeTo: .title3))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(localized: "gizli an"))
                        .font(Brand.scaledFont(size: 10, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

                // Video indicator overlay
                if strip.isVideo {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "play.fill")
                                    .font(Brand.scaledFont(size: 8, relativeTo: .caption))
                                if let dur = strip.videoDuration {
                                    Text(String(format: "%.0fs", dur))
                                        .font(Brand.scaledFont(size: 9, weight: .medium, relativeTo: .caption))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(6)
                        }
                        Spacer()
                    }
                }

                Text(strip.timestamp, style: .relative)
                    .font(Brand.scaledFont(size: 10, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(8)
            }
        }
        .overlay(alignment: .topLeading) {
            if showUnseenDot {
                HistoryUnseenDot()
                    .padding(8)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if locked {
                // Same explainer as the feed card — rule first, camera second.
                HapticsManager.playImpact(style: .light)
                showLockedExplainer = true
            } else {
                onTap()
            }
        }
        .sheet(isPresented: $showLockedExplainer) {
            SecretLockedExplainerSheet()
        }
        .contextMenu {
            if let onReport = onReport {
                Button(role: .destructive) {
                    onReport()
                } label: {
                    Label(String(localized: "fotoğrafı bildir"), systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}

// MARK: - Unseen Dot

/// Small white dot marking a strip the current user received but has not
/// opened yet. Mirrors the unread badge on PhotoDetailView's receiver bar.
struct HistoryUnseenDot: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(
                Circle().stroke(Color.black.opacity(0.5), lineWidth: 2)
            )
            .accessibilityLabel(String(localized: "yeni an"))
    }
}

// MARK: - Weekly Cover Card

/// Full-width "haftan hazır." cover shown at the top of the history feed when
/// the current week already has a computed rollcall summary. Tapping opens
/// the WeeklyRecapStoryView via the parent.
struct HistoryWeeklyCoverCard: View {
    let summary: RollcallSummary
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticsManager.playImpact(style: .light)
            onTap()
        } label: {
            HStack(spacing: 14) {
                // Thumbnail with play affordance
                ZStack {
                    if let thumb = summary.thumbnailUrl, let url = URL(string: thumb) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.white.opacity(0.06))
                        }
                    } else {
                        Rectangle().fill(Color.white.opacity(0.06))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .overlay {
                    Image(systemName: "play.fill")
                        .font(Brand.scaledFont(size: 12, relativeTo: .footnote))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Color.black.opacity(0.45), in: Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "hafta özeti"))
                        .sectionHeader()
                    Text(String(localized: "haftan hazır."))
                        .font(Brand.scaledFont(size: 17, weight: .bold, relativeTo: .body))
                        .foregroundStyle(.white)
                    Text(String(localized: "\(summary.photosCount) an birikti."))
                        .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(Brand.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
            .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "haftan hazır."))
        .accessibilityHint(String(localized: "haftalık özeti aç"))
    }
}

// MARK: - Sender Avatar

struct HistorySenderAvatar: View {
    let avatarUrl: String?
    let onLoad: () -> Void

    var body: some View {
        if let url = avatarUrl.flatMap({ URL(string: $0) }), avatarUrl != nil && !avatarUrl!.isEmpty {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.white.opacity(0.15))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(Brand.scaledFont(size: 13, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .task {
                    onLoad()
                }
        }
    }
}

// MARK: - Monthly Section

struct HistoryMonthlySection: View {
    let summaries: [MonthlySummary]
    let onSelect: (MonthlySummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "aylık özetler"))
                    .font(Brand.scaledFont(size: 15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(summaries) { monthly in
                        Button {
                            onSelect(monthly)
                        } label: {
                            MonthlyRecapCard(summary: monthly)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        TabBarState.shared.isSwipeDisabled = true
                    }
                    .onEnded { _ in
                        Task { try? await Task.sleep(for: .seconds(0.35)); TabBarState.shared.isSwipeDisabled = false }
                    }
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Rollcall Section

struct HistoryRollcallSection: View {
    let summaries: [RollcallSummary]
    let onSelect: (RollcallSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "özetler"))
                    .font(Brand.scaledFont(size: 15, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(summaries) { summary in
                        Button {
                            onSelect(summary)
                        } label: {
                            RollcallCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        TabBarState.shared.isSwipeDisabled = true
                    }
                    .onEnded { _ in
                        Task { try? await Task.sleep(for: .seconds(0.35)); TabBarState.shared.isSwipeDisabled = false }
                    }
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Empty State

struct HistoryEmptyState: View {
    @AppStorage("show_history_empty_warm_note") private var showWarmEmptyNote = true

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            if showWarmEmptyNote {
                WarmNoteCard(
                    eyebrow: String(localized: "geçmiş"),
                    title: String(localized: "burası zamanla sizin küçük arşiviniz olur"),
                    message: String(localized: "ilk fotoğrafı gönderdiğinde geçmiş geri kalanını sessizce toplar."),
                    dismissLabel: String(localized: "tamam"),
                    onDismiss: {
                        withAnimation(Brand.Animations.fade) {
                            showWarmEmptyNote = false
                        }
                    }
                )
                .padding(.horizontal, 20)
            }

            EmptyStateView(
                icon: "camera.aperture",
                title: String(localized: "henüz bir an düşmedi"),
                subtitle: String(localized: "ilk fotoğrafı gönder,\nanlarınız burada birikmeye başlasın."),
                actionLabel: String(localized: "fotoğraf çek"),
                action: { TabBarState.shared.selectedTab = .camera }
            )
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Map View

struct HistoryMapView: View {
    let strips: [Strip]
    let currentUserId: String?
    @Binding var position: MapCameraPosition
    let onPhotoTap: (PhotoMetadata) -> Void

    var body: some View {
        let myId = currentUserId ?? ""
        let annotations = strips.prefix(500).compactMap { strip -> PhotoAnnotation? in
            guard let lat = strip.latitude, let lon = strip.longitude else { return nil }
            guard !strip.isLockedFor(myId) else { return nil }
            return PhotoAnnotation(id: strip.id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), photo: strip.asMetadata)
        }

        let gridSize = 0.045
        var clusters: [String: [PhotoAnnotation]] = [:]
        for annotation in annotations {
            let key = "\(Int(annotation.coordinate.latitude / gridSize))_\(Int(annotation.coordinate.longitude / gridSize))"
            clusters[key, default: []].append(annotation)
        }

        struct ClusterPin: Identifiable {
            let id: String
            let coordinate: CLLocationCoordinate2D
            let count: Int
            let representativePhoto: PhotoMetadata
        }

        let clusterPins: [ClusterPin] = clusters.compactMap { key, items in
            guard let firstItem = items.first else { return nil }
            let avgLat = items.map(\.coordinate.latitude).reduce(0, +) / Double(items.count)
            let avgLon = items.map(\.coordinate.longitude).reduce(0, +) / Double(items.count)
            return ClusterPin(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                count: items.count,
                representativePhoto: firstItem.photo
            )
        }

        return Map(position: $position) {
            ForEach(clusterPins) { pin in
                Annotation("", coordinate: pin.coordinate) {
                    ZStack {
                        CachedAsyncImage(url: URL(string: pin.representativePhoto.smallThumbnailUrl ?? pin.representativePhoto.thumbnailUrl ?? pin.representativePhoto.imageUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        } placeholder: {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }

                        if pin.count > 1 {
                            Text("\(pin.count)")
                                .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white, in: Capsule())
                                .offset(x: 18, y: -18)
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    .onTapGesture { onPhotoTap(pin.representativePhoto) }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .ignoresSafeArea(edges: .bottom)
    }
}
