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
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showNotifications = false
    @State private var unreadCount = 0
    @State private var feedDestination: FeedDestination?
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
    private var networkMonitor = NetworkMonitor.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Custom Header
                header
                
                // Offline Banner
                if !networkMonitor.isConnected {
                    offlineBanner
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
        .onChange(of: isMapView) { _, newValue in
            TabBarState.shared.isSwipeDisabled = newValue
        }
        .onDisappear {
            TabBarState.shared.isSwipeDisabled = false
        }
        .onAppear {
            if lastRollcallCount != localStrips.count {
                lastRollcallCount = localStrips.count
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
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                title: "fotoğrafı bildir",
                subtitle: "bu fotoğrafı neden bildiriyorsun?"
            ) { reason in
                Task {
                    if let strip = reportTargetStrip {
                        try? await DependencyContainer.shared.userRepository.reportContent(
                            contentType: "photo",
                            contentId: strip.id,
                            contentOwnerId: strip.senderId,
                            reason: reason
                        )
                    }
                    reportTargetStrip = nil
                    showReportSheet = false
                    HapticsManager.playNotification(type: .success)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .alert("geçmişi temizle?", isPresented: $showDeleteAlert) {
            Button("sil", role: .destructive) {
                Task {
                    isDeleting = true
                    try? await DependencyContainer.shared.stripRepository.clearHistory()
                    isDeleting = false
                }
            }
            Button("iptal", role: .cancel) {}
        } message: {
            Text("gönderdiğin tüm fotoğraflar kalıcı olarak silinecek.")
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
        VStack(spacing: 8) {
            // Brand logotype
            Text("anlık.")
                .font(.system(size: 22, weight: .black, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            
            HStack(alignment: .center) {
                // Notification bell
                Button {
                    HapticsManager.playImpact(style: .light)
                    showNotifications = true
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
                .accessibilityLabel("bildirimler")
                .accessibilityHint(unreadCount > 0 ? "\(unreadCount) okunmamış bildirim" : "bildirim yok")
                
                Spacer()
                
                // View toggle pill
                HStack(spacing: 0) {
                    toggleButton(title: "akış", icon: "square.grid.2x2", isActive: !isMapView) {
                        isMapView = false
                    }
                    toggleButton(title: "harita", icon: "map", isActive: isMapView) {
                        isMapView = true
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                
                Spacer()
                
                // Delete button
                Button {
                    HapticsManager.playImpact(style: .medium)
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("geçmişi temizle")
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private func toggleButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticsManager.playSelection()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
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
    
    // MARK: - Offline Banner
    
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .bold))
            Text("çevrimdışı")
                .font(.system(size: 12, weight: .semibold))

            Button {
                HapticsManager.playImpact(style: .light)
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("tekrar dene")
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
            } else if localStrips.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Monthly summaries (aylık, haftalıkların üstünde)
                        if !cachedMonthly.isEmpty {
                            monthlySection
                        }

                        // Rollcall summaries (haftalık)
                        if !cachedRollcall.isEmpty {
                            rollcallSection
                        }
                        
                        // Feed
                        if feedLayout == "grid" {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                                ForEach(localStrips, id: \.id) { strip in
                                    gridCard(for: strip)
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .onAppear {
                                            if strip.id == localStrips.last?.id {
                                                Task { await viewModel.loadMore(oldestTimestamp: strip.timestamp) }
                                            }
                                        }
                                }
                            }
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(localStrips, id: \.id) { strip in
                                    feedCard(for: strip)
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        .onAppear {
                                            if strip.id == localStrips.last?.id {
                                                Task { await viewModel.loadMore(oldestTimestamp: strip.timestamp) }
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
            }
        }
    }
    
    // MARK: - Feed Card
    
    private func feedCard(for strip: Strip) -> some View {
        let isSentByMe = strip.senderId == viewModel.currentUserId
        let dataSaver = UserDefaults.standard.bool(forKey: "data_saver_mode")
        let feedUrl = URL(string: dataSaver ? (strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl) : (strip.thumbnailUrl ?? strip.imageUrl))
        
        return ZStack(alignment: .bottom) {
            // Image
            CachedAsyncImage(url: feedUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 400)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 400)
                    .overlay {
                        ProgressView().tint(.white.opacity(0.2))
                    }
            }
            
            // Bottom gradient overlay
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
            
            // Info bar
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    // Direction indicator
                    HStack(spacing: 4) {
                        Image(systemName: isSentByMe ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 9, weight: .bold))
                        Text(isSentByMe ? "gönderildi" : "alındı")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    
                    // Location or time
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
                
                // Chat bubble
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
        .contentShape(Rectangle())
        .onTapGesture { feedDestination = .chat(strip.asMetadata) }
        .contextMenu {
            if isSentByMe {
                Button(role: .destructive) {
                    Task { await viewModel.deleteStrip(strip.asMetadata) }
                } label: {
                    Label("kalıcı olarak sil", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    reportTargetStrip = strip
                    showReportSheet = true
                } label: {
                    Label("fotoğrafı bildir", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
    
    // MARK: - Grid Card (compact)
    
    private func gridCard(for strip: Strip) -> some View {
        let feedUrl = URL(string: strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl)
        
        return ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: feedUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 180, maxHeight: 180)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 180)
            }
            
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            
            Text(strip.timestamp, style: .relative)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture { feedDestination = .chat(strip.asMetadata) }
        .contextMenu {
            if strip.senderId != viewModel.currentUserId {
                Button(role: .destructive) {
                    reportTargetStrip = strip
                    showReportSheet = true
                } label: {
                    Label("fotoğrafı bildir", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
    
    // MARK: - Monthly Section

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("aylık özetler")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cachedMonthly) { monthly in
                        Button {
                            selectedMonthlySummary = monthly
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            TabBarState.shared.isSwipeDisabled = false
                        }
                    }
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Rollcall Section

    private var rollcallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("özetler")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cachedRollcall) { summary in
                        Button {
                            selectedSummary = summary
                        } label: {
                            RollcallCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            // Block the parent tab-swipe gesture while scrolling summaries
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        TabBarState.shared.isSwipeDisabled = true
                    }
                    .onEnded { _ in
                        // Delay re-enable so the parent gesture doesn't pick up
                        // residual momentum after the scroll hits its boundary
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            TabBarState.shared.isSwipeDisabled = false
                        }
                    }
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        let annotations = localStrips.compactMap { strip -> PhotoAnnotation? in
            guard let lat = strip.latitude, let lon = strip.longitude else { return nil }
            return PhotoAnnotation(id: strip.id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), photo: strip.asMetadata)
        }
        
        return Map(position: $position) {
            ForEach(annotations) { annotation in
                Annotation("", coordinate: annotation.coordinate) {
                    CachedAsyncImage(url: URL(string: annotation.photo.smallThumbnailUrl ?? annotation.photo.thumbnailUrl ?? annotation.photo.imageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    } placeholder: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                    .onTapGesture { feedDestination = .chat(annotation.photo) }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            EmptyStateView(
                icon: "camera.aperture",
                title: "henüz bir an yok",
                subtitle: "bir arkadaşına fotoğraf gönder,\nanlarınız burada biriksin.",
                actionLabel: "fotoğraf çek",
                action: { TabBarState.shared.selectedTab = .camera }
            )
            Spacer()
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
    
    /// Compute rollcall summaries from localStrips. Called only when strip count changes.
    private func computeRollcallSummaries() -> [RollcallSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: localStrips) { strip in
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: strip.timestamp)
        }
        
        return grouped.map { (components, strips) in
            let sortedStrips = strips.sorted { $0.timestamp > $1.timestamp }
            let weekNumber = components.weekOfYear ?? 0
            let year = components.yearForWeekOfYear ?? 0
            let referenceDate = sortedStrips.first?.timestamp ?? Date()
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
            let start = weekInterval?.start ?? (calendar.date(from: components) ?? Date())
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            
            return RollcallSummary(
                weekNumber: weekNumber,
                year: year,
                photosCount: strips.count,
                thumbnailUrl: sortedStrips.first?.imageUrl,
                startDate: start,
                endDate: end
            )
        }.sorted { $0.startDate > $1.startDate }
    }
    
    /// Legacy computed property — kept for backward compat, delegates to cache.
    private var rollcallSummaries: [RollcallSummary] { cachedRollcall }
    
    // MARK: - Sending Overlay
    
    private var sendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [.white, .white.opacity(0.2)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(sendingRotation))
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("gönderiliyor...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                sendingRotation = 360
            }
        }
        .onDisappear {
            sendingRotation = 0
        }
    }
    
    @State private var sendingRotation: Double = 0
}
