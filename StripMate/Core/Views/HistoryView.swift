import SwiftUI
import MapKit
import FirebaseFirestore
import SwiftData

struct PhotoAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let photo: PhotoMetadata
}

enum FeedDestination: Identifiable {
    case chat(PhotoMetadata)

    var id: String {
        switch self {
        case .chat(let p): return "chat_\(p.id)"
        }
    }
}

public struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @State private var isMapView = false
    @State private var position: MapCameraPosition = .automatic
    // @Query isolated: only triggers re-render when Strip data actually changes
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]
    @Query(filter: #Predicate<Friend> { !$0.isPending }) private var localFriends: [Friend]
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showNotifications = false
    @State private var showCalendarCapsule = false
    @State private var unreadCount = 0
    @State private var feedDestination: FeedDestination?
    @State private var senderAvatarCache: [String: String] = [:]
    /// Tracks in-flight avatar fetches to prevent duplicate requests
    @State private var avatarFetchInFlight: Set<String> = []
    @State private var previouslyLockedIds: Set<String> = []
    @State private var unlockingStrip: Strip?
    @State private var selectedSummary: RollcallSummary?
    @State private var selectedMonthlySummary: MonthlySummary?
    @AppStorage("feed_layout") private var feedLayout: String = "single"
    /// Cached rollcall summaries — recomputed only when localStrips.count changes.
    @State private var cachedRollcall: [RollcallSummary] = []
    @State private var cachedMonthly: [MonthlySummary] = []
    @State private var friendNameCache: [String: String] = [:]
    @State private var lastRollcallCount: Int = -1
    @State private var showReportSheet = false
    @State private var reportTargetStrip: Strip?
    @State private var searchText: String = ""
    @State private var showMemoryDetail = false
    /// duygusal-7: full-screen MemoriesView (Ken Burns slideshow) entry.
    @State private var showMemories = false
    /// guven-6: report failed — surfaced over the report sheet.
    @State private var showReportError = false
    /// Shared namespace for the card → detail zoom transition.
    @Namespace private var photoZoom
    /// Feed scroll offset (0 at rest) driving the quiet header collapse.
    @State private var feedScrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var networkMonitor = NetworkMonitor.shared

    public init() {}

    /// Cached Turkish date formatter — DateFormatter allocation is expensive, reuse across search calls
    private static let turkishDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.current
        return df
    }()

    /// 0→1 collapse factor over the first ~90pt of feed scroll.
    private var headerCollapse: CGFloat {
        min(1, max(0, feedScrollOffset / 90))
    }

    /// Strips filtered by search text (sender name, city, date)
    private var filteredStrips: [Strip] {
        guard !searchText.isEmpty else { return localStrips }
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        let dateFormatter = Self.turkishDateFormatter

        return localStrips.filter { strip in
            // Match city name
            if let city = strip.cityName, city.lowercased().contains(query) {
                return true
            }
            // Match sender name from friendNameCache
            if let name = friendNameCache[strip.senderId], name.lowercased().contains(query) {
                return true
            }
            // Match sender avatar cache key (username lookup via senderAvatarCache is indirect, skip)
            // Match date — try multiple formats
            dateFormatter.dateFormat = "d MMMM yyyy"
            let longDate = dateFormatter.string(from: strip.timestamp).lowercased()
            if longDate.contains(query) { return true }

            dateFormatter.dateFormat = "d MMMM"
            let shortDate = dateFormatter.string(from: strip.timestamp).lowercased()
            if shortDate.contains(query) { return true }

            dateFormatter.dateFormat = "MMMM yyyy"
            let monthYear = dateFormatter.string(from: strip.timestamp).lowercased()
            if monthYear.contains(query) { return true }

            return false
        }
    }

    /// Strips from any previous year on today's date
    private var memoryStrips: [Strip] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day], from: Date())
        let currentYear = calendar.component(.year, from: Date())
        return localStrips.filter { strip in
            let comp = calendar.dateComponents([.year, .month, .day], from: strip.timestamp)
            return comp.month == today.month && comp.day == today.day && (comp.year ?? currentYear) < currentYear
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Custom Header
                header

                // Offline Banner
                if !networkMonitor.isConnected {
                    offlineBanner
                } else if viewModel.isReconnecting {
                    // guven-11: listener died while the network is up — the
                    // feed would otherwise freeze in the past looking healthy.
                    reconnectingBanner
                }

                // Content
                if isMapView {
                    mapView
                        .transition(.opacity)
                } else {
                    feedView
                        .transition(.opacity)
                }
            }

            // Sending banner removed — now shown globally in MainTabView
        }
        .task(id: "history-listener") {
            await viewModel.listenToPhotos()
        }
        .task(id: "notification-badge") {
            let stream = DependencyContainer.shared.notificationRepository.listenToNotifications()
            for await notifications in stream {
                guard !Task.isCancelled else { break }
                self.unreadCount = notifications.filter { !$0.isRead }.count
            }
        }
        .onChange(of: localStrips.count) { _, newCount in
            if newCount != lastRollcallCount {
                lastRollcallCount = newCount
                recomputeSummaries()
            }
        }
        .onChange(of: isMapView) { _, newValue in
            TabBarState.shared.isSwipeDisabled = newValue
        }
        // Detect secret strips that just got unlocked — use count-based trigger instead of O(n) string array
        .onChange(of: localStrips.count) { _, _ in
            detectUnlockedStrips()
        }
        .onChange(of: localStrips.filter(\.isSecret).flatMap(\.unlockedBy).count) { _, _ in
            detectUnlockedStrips()
        }
        .fullScreenCover(item: $unlockingStrip) { strip in
            // Animasyon bittikten sonra direkt chat'e geçiş — tek ekranda
            SecretUnlockAnimation(
                photoUrl: strip.thumbnailUrl ?? strip.imageUrl,
                strip: strip
            )
        }
        .onDisappear {
            TabBarState.shared.isSwipeDisabled = false
        }
        .onAppear {
            // Build friend name cache from SwiftData
            buildFriendNameCache()
            // Initialize locked IDs tracking
            if let myId = viewModel.currentUserId {
                previouslyLockedIds = Set(localStrips.filter { strip in
                    strip.isSecret && strip.senderId != myId && !strip.unlockedBy.contains(myId)
                }.map(\.id))
            }
            if lastRollcallCount != localStrips.count {
                lastRollcallCount = localStrips.count
                recomputeSummaries()
            }
        }
        .onChange(of: localFriends.count) { _, _ in
            buildFriendNameCache()
            recomputeSummaries()
        }
        // Deep link: the weeklySummary push / notification row posts
        // "openWeeklyRecap" — present the latest cached recap as a story.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openWeeklyRecap"))) { _ in
            if cachedRollcall.isEmpty {
                buildFriendNameCache()
                recomputeSummaries()
            }
            if let latest = cachedRollcall.first {
                selectedSummary = latest
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
        }
        .errorAlert(errorMessage: $viewModel.errorMessage)
        .sheet(item: $feedDestination) { destination in
            switch destination {
            case .chat(let photo):
                let isMine = photo.senderId == viewModel.currentUserId
                PhotoDetailView(photo: photo, isSentByMe: isMine)
                    .navigationTransition(.zoom(sourceID: photo.id, in: photoZoom))
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
                    .presentationBackground(.black)
            }
        }
        .fullScreenCover(item: $selectedSummary) { summary in
            let calendar = Calendar.current
            let weekStrips = localStrips.filter { strip in
                let comp = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: strip.timestamp)
                return comp.weekOfYear == summary.weekNumber && comp.yearForWeekOfYear == summary.year
            }
            WeeklyRecapStoryView(summary: summary, strips: Array(weekStrips))
        }
        .fullScreenCover(item: $selectedMonthlySummary) { monthly in
            let calendar = Calendar.current
            let monthStrips = localStrips.filter { strip in
                let comp = calendar.dateComponents([.year, .month], from: strip.timestamp)
                return comp.month == monthly.month && comp.year == monthly.year
            }
            MonthlyRecapStoryView(summary: monthly, strips: Array(monthStrips))
        }
        .fullScreenCover(isPresented: $showMemoryDetail) {
            MemoryDetailView(strips: memoryStrips)
        }
        // duygusal-7: the memories cinema, previously unreachable dead code.
        .fullScreenCover(isPresented: $showMemories) {
            MemoriesView()
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                title: "fotoğrafı bildir",
                subtitle: "bu fotoğrafı neden bildiriyorsun?"
            ) { reason in
                Task { await reportStrip(reason: reason) }
            }
            // guven-6: failure surfaces over the sheet; it stays open for retry.
            .alert(String(localized: "bildirilemedi — tekrar dene."), isPresented: $showReportError) {
                Button(String(localized: "tamam"), role: .cancel) {}
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showCalendarCapsule) {
            CalendarCapsuleView()
        }
        .alert(String(localized: "tüm anları silmek istediğine emin misin?"), isPresented: $showDeleteAlert) {
            Button(String(localized: "sil"), role: .destructive) {
                Task {
                    isDeleting = true
                    try? await DependencyContainer.shared.stripRepository.clearHistory()
                    isDeleting = false
                }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "bu işlem geri alınamaz."))
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HistoryHeaderView(
            unreadCount: unreadCount,
            isMapView: $isMapView,
            onNotificationsTap: { showNotifications = true },
            onCalendarTap: { showCalendarCapsule = true },
            onDeleteTap: { showDeleteAlert = true }
        )
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HistoryOfflineBanner {
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Reconnecting Banner

    /// guven-11: quiet twin of the offline banner — shown when the Firestore
    /// listener stalled and the view model is re-subscribing with backoff.
    private var reconnectingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
            Text(String(localized: "güncellenemiyor — yeniden bağlanıyor."))
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Feed View

    private var feedView: some View {
        Group {
            if viewModel.isLoading && localStrips.isEmpty {
                // Skeleton loading
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonStripCard()
                        }
                    }
                    .padding(.top, 8)
                }
            } else if localStrips.isEmpty, viewModel.errorMessage != nil {
                errorState
            } else if localStrips.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Search bar + memories entry (duygusal-7)
                        HStack(spacing: 10) {
                            searchBar
                            CircleIconButton(
                                icon: "photo.stack",
                                size: 36,
                                iconSize: 14,
                                accessibilityLabel: "anılar"
                            ) {
                                HapticsManager.playImpact(style: .light)
                                showMemories = true
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                        // Weekly recap cover — "haftan hazır." (duygusal-3)
                        if let weekly = currentWeekSummary, searchText.isEmpty {
                            HistoryWeeklyCoverCard(summary: weekly) {
                                selectedSummary = weekly
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }

                        // Memory card — "today last year"
                        if !memoryStrips.isEmpty && searchText.isEmpty {
                            MemoryCardView(strips: memoryStrips)
                                .onTapGesture {
                                    HapticsManager.playImpact(style: .light)
                                    showMemoryDetail = true
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        // Feed
                        let displayStrips = filteredStrips
                        if displayStrips.isEmpty && !searchText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(Brand.scaledFont(size: 28, relativeTo: .title2))
                                    .foregroundStyle(.white.opacity(0.2))
                                Text(String(localized: "bir şey bulamadık"))
                                    .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if feedLayout == "grid" {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                                ForEach(displayStrips, id: \.id) { strip in
                                    gridCard(for: strip)
                                        .scrollTransition(.interactive) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : 0.4)
                                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                        }
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .onAppear {
                                            if strip.id == localStrips.last?.id {
                                                Task { await viewModel.loadMore(oldestTimestamp: strip.timestamp) }
                                            }
                                            // Warm the video cache as cards
                                            // appear so opening the detail
                                            // view plays from disk instantly.
                                            if let v = strip.videoUrl, let url = URL(string: v) {
                                                VideoPlayerView.prefetch(url)
                                            }
                                        }
                                }
                            }
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(displayStrips, id: \.id) { strip in
                                    feedCard(for: strip)
                                        .scrollTransition(.interactive) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : 0.4)
                                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                        }
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .onAppear {
                                            if strip.id == localStrips.last?.id {
                                                Task { await viewModel.loadMore(oldestTimestamp: strip.timestamp) }
                                            }
                                            if let v = strip.videoUrl, let url = URL(string: v) {
                                                VideoPlayerView.prefetch(url)
                                            }
                                        }
                                }
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.bottom, 120)
                }
                .refreshable {
                    HapticsManager.playImpact(style: .light)
                    await viewModel.refresh()
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, newValue in
                    feedScrollOffset = max(0, newValue)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HistorySearchBar(searchText: $searchText)
    }

    // MARK: - Feed Card

    private func feedCard(for strip: Strip) -> some View {
        let isSentByMe = strip.senderId == viewModel.currentUserId
        let locked = isStripLocked(strip)

        return HistoryFeedCard(
            strip: strip,
            isSentByMe: isSentByMe,
            locked: locked,
            senderAvatarUrl: senderAvatarCache[strip.senderId],
            seenLabel: seenLabel(for: strip, isSentByMe: isSentByMe),
            showUnseenDot: isUnseenByMe(strip, isSentByMe: isSentByMe),
            onTap: { feedDestination = .chat(strip.asMetadata) },
            onDelete: { Task { await viewModel.deleteStrip(strip.asMetadata) } },
            onReport: {
                reportTargetStrip = strip
                showReportSheet = true
            },
            onSenderAvatarLoad: { loadSenderAvatar(for: strip.senderId) }
        )
        .matchedTransitionSource(id: strip.id, in: photoZoom)
    }

    // MARK: - Seen / Unseen Helpers

    /// Sender-side label: nil while nobody opened the strip (card keeps
    /// showing "gönderildi"), otherwise a "görüldü" variant.
    private func seenLabel(for strip: Strip, isSentByMe: Bool) -> String? {
        guard isSentByMe else { return nil }
        let seenByOthers = strip.seenBy.filter { $0 != strip.senderId }
        guard !seenByOthers.isEmpty else { return nil }
        if seenByOthers.count == 1 {
            if let name = friendNameCache[seenByOthers[0]] {
                return String(localized: "\(name) gördü")
            }
            return String(localized: "görüldü")
        }
        return String(localized: "\(seenByOthers.count) kişi gördü")
    }

    /// Receiver-side unseen state: the current user received this strip and
    /// hasn't opened it yet.
    private func isUnseenByMe(_ strip: Strip, isSentByMe: Bool) -> Bool {
        guard !isSentByMe, let myId = viewModel.currentUserId else { return false }
        return !strip.seenBy.contains(myId)
    }

    // MARK: - Secret Strip Check

    /// Check if a strip is locked (secret + not unlocked for current user)
    private func isStripLocked(_ strip: Strip) -> Bool {
        guard strip.isSecret else { return false }
        let isMine = strip.senderId == viewModel.currentUserId
        if isMine { return false }
        guard let myId = viewModel.currentUserId else { return true }
        return !strip.unlockedBy.contains(myId)
    }

    // MARK: - Report (guven-6)

    /// Verified report: success feedback fires only after the write lands.
    /// On failure the sheet stays open and an error alert offers a retry.
    private func reportStrip(reason: String) async {
        guard let strip = reportTargetStrip else {
            showReportSheet = false
            return
        }
        do {
            try await DependencyContainer.shared.userRepository.reportContent(
                contentType: "photo",
                contentId: strip.id,
                contentOwnerId: strip.senderId,
                reason: reason
            )
            reportTargetStrip = nil
            showReportSheet = false
            HapticsManager.playNotification(type: .success)
        } catch {
            HapticsManager.playNotification(type: .error)
            showReportError = true
        }
    }

    // MARK: - Sender Avatar Helper

    private func loadSenderAvatar(for senderId: String) {
        guard senderAvatarCache[senderId] == nil, !avatarFetchInFlight.contains(senderId) else { return }
        avatarFetchInFlight.insert(senderId)
        Task {
            let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: senderId)
            senderAvatarCache[senderId] = profile?.avatarUrl ?? ""
            avatarFetchInFlight.remove(senderId)
        }
    }

    // MARK: - Secret Strip Unlock Detection

    private func detectUnlockedStrips() {
        guard let myId = viewModel.currentUserId else { return }
        for strip in localStrips where strip.isSecret && strip.senderId != myId {
            let wasLocked = previouslyLockedIds.contains(strip.id)
            let isNowUnlocked = strip.unlockedBy.contains(myId)
            if wasLocked && isNowUnlocked {
                unlockingStrip = strip
                previouslyLockedIds.remove(strip.id)
                break
            }
        }
        previouslyLockedIds = Set(localStrips.filter { strip in
            strip.isSecret && strip.senderId != myId && !strip.unlockedBy.contains(myId)
        }.map(\.id))
    }

    // MARK: - Grid Card

    private func gridCard(for strip: Strip) -> some View {
        let locked = isStripLocked(strip)
        let isMine = strip.senderId == viewModel.currentUserId

        return HistoryGridCard(
            strip: strip,
            locked: locked,
            showUnseenDot: isUnseenByMe(strip, isSentByMe: isMine),
            onTap: { feedDestination = .chat(strip.asMetadata) },
            onReport: isMine ? nil : {
                reportTargetStrip = strip
                showReportSheet = true
            }
        )
        .matchedTransitionSource(id: strip.id, in: photoZoom)
    }

    // MARK: - Monthly Section

    private var monthlySection: some View {
        HistoryMonthlySection(summaries: cachedMonthly) { monthly in
            selectedMonthlySummary = monthly
        }
    }

    // MARK: - Rollcall Section

    private var rollcallSection: some View {
        HistoryRollcallSection(summaries: cachedRollcall) { summary in
            selectedSummary = summary
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        HistoryMapView(
            strips: Array(localStrips),
            currentUserId: viewModel.currentUserId,
            position: $position,
            onPhotoTap: { photo in feedDestination = .chat(photo) }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HistoryEmptyState()
    }

    // MARK: - Error State

    /// Shown when history failed to load and there is nothing cached locally.
    private var errorState: some View {
        VStack {
            Spacer()
            ErrorStateView(message: viewModel.errorMessage) {
                Task { await viewModel.refresh() }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func photoDetailSheet(for photo: PhotoMetadata) -> some View {
        let isMine = photo.senderId == viewModel.currentUserId
        if isMine {
            PhotoDetailView(photo: photo, isSentByMe: true) {
                await viewModel.deleteStrip(photo)
            }
        } else {
            PhotoDetailView(photo: photo, isSentByMe: false)
        }
    }

    /// Legacy computed property — kept for backward compat, delegates to cache.
    private var rollcallSummaries: [RollcallSummary] { cachedRollcall }

    /// Rollcall summary for the current ISO week, if the week already has
    /// strips. Drives the "haftan hazır." cover card at the top of the feed.
    private var currentWeekSummary: RollcallSummary? {
        let comp = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cachedRollcall.first {
            $0.weekNumber == comp.weekOfYear && $0.year == comp.yearForWeekOfYear && $0.photosCount > 0
        }
    }

    /// Build friendNameCache from SwiftData Friend records
    private func buildFriendNameCache() {
        var cache: [String: String] = [:]
        for friend in localFriends {
            if let name = friend.profile?.displayName ?? friend.profile?.username {
                cache[friend.userId] = name
            }
        }
        if cache != friendNameCache {
            friendNameCache = cache
        }
    }

    /// Recompute weekly + monthly summaries from current data
    private func recomputeSummaries() {
        let stripsArray = Array(localStrips)
        cachedRollcall = RollcallComputer.computeWeeklySummaries(
            from: stripsArray,
            friendNameCache: friendNameCache
        )
        cachedMonthly = RollcallComputer.computeMonthlySummaries(
            from: stripsArray,
            weeklySummaries: cachedRollcall,
            friendNameCache: friendNameCache
        )
    }

}
