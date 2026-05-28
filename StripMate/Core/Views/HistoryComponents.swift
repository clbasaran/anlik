import SwiftUI
import MapKit

// MARK: - History Search Bar

struct HistorySearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))

            TextField("", text: $searchText, prompt: Text("ara... \u{015F}ehir, arkada\u{015F} veya tarih")
                .foregroundStyle(.white.opacity(0.3))
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
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
                .font(.system(size: 22, weight: .black, design: .default))
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
                                .font(.system(size: 16, weight: .semibold))
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
                            .font(.system(size: 15, weight: .semibold))
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
                            .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 11, weight: .bold))
            Text(String(localized: "bağlantı yok"))
                .font(.system(size: 12, weight: .semibold))

            Button {
                HapticsManager.playImpact(style: .light)
                onRetry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(localized: "yenile"))
                        .font(.system(size: 11, weight: .bold))
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

// MARK: - Feed Card

struct HistoryFeedCard: View {
    let strip: Strip
    let isSentByMe: Bool
    let locked: Bool
    let senderAvatarUrl: String?
    let onTap: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onSenderAvatarLoad: () -> Void

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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(String(localized: "bu anı görmek için sen de bir an paylaş"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Spacer()

                    HStack(spacing: 8) {
                        HistorySenderAvatar(avatarUrl: senderAvatarUrl, onLoad: onSenderAvatarLoad)
                        Text(strip.timestamp, style: .relative)
                            .font(.system(size: 12, weight: .medium))
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
                                    .font(.system(size: 9))
                                Text(String(localized: "gizli"))
                                    .font(.system(size: 10, weight: .bold))
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
                                    Image(systemName: isSentByMe ? "arrow.up.right" : "arrow.down.left")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(isSentByMe ? String(localized: "gönderildi") : String(localized: "alındı"))
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.white.opacity(0.5))

                                HStack(spacing: 4) {
                                    if let city = strip.cityName {
                                        Text(city)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Text(strip.timestamp, style: .relative)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }

                            Spacer()

                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 14))
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
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if locked {
                // Locked secret: jump to camera so the user can share a moment
                // and unlock the secret. Same intent as the gizli-an unlock flow.
                TabBarState.shared.selectedTab = .camera
                HapticsManager.playImpact(style: .light)
            } else {
                onTap()
            }
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
    let onTap: () -> Void
    let onReport: (() -> Void)?

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
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(localized: "gizli an"))
                        .font(.system(size: 10, weight: .bold))
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
                                    .font(.system(size: 8))
                                if let dur = strip.videoDuration {
                                    Text(String(format: "%.0fs", dur))
                                        .font(.system(size: 9, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(8)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if locked {
                TabBarState.shared.selectedTab = .camera
                HapticsManager.playImpact(style: .light)
            } else {
                onTap()
            }
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
                        .font(.system(size: 13))
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
                    .font(.system(size: 15, weight: .bold))
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
                    .font(.system(size: 15, weight: .bold))
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
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
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
