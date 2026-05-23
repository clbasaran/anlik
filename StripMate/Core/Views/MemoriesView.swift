import SwiftUI
import SwiftData
import FirebaseAuth

struct MemoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MemoriesViewModel()
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]
    @Query(filter: #Predicate<Friend> { !$0.isPending }) private var localFriends: [Friend]
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Ken Burns
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero

    // Swipe-down dismiss
    @State private var dismissOffset: CGSize = .zero
    @State private var gestureDirection: Axis? = nil

    // Slide transition direction
    @State private var slideDirection: Edge = .trailing

    var filterFriendId: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.photos.isEmpty {
                emptyState
            } else {
                // Photo slideshow
                photoContent
                    .offset(y: max(0, dismissOffset.height))
                    .opacity(1.0 - min(abs(dismissOffset.height) / 400.0, 0.5))

                // Overlays
                VStack(spacing: 0) {
                    // Progress bar
                    progressBar
                        .padding(.top, 8)
                        .padding(.horizontal, 12)

                    // Top controls
                    topControls
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    Spacer()

                    // Bottom metadata + controls
                    bottomOverlay
                }
                .offset(y: max(0, dismissOffset.height))
                .opacity(1.0 - min(abs(dismissOffset.height) / 400.0, 0.5))

                // Tap-to-pause overlay
                if !viewModel.isPlaying {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.7))
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            buildFriendNameCache()
            viewModel.filterFriendId = filterFriendId
            viewModel.loadPhotos(from: Array(localStrips))
            viewModel.startTimer()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.loadPhotos(from: Array(localStrips))
            if viewModel.isPlaying {
                viewModel.startTimer()
            }
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            triggerKenBurns()
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    if gestureDirection == nil {
                        gestureDirection = abs(value.translation.width) > abs(value.translation.height)
                            ? .horizontal : .vertical
                    }

                    if gestureDirection == .vertical {
                        dismissOffset = value.translation
                    } else if gestureDirection == .horizontal {
                        // Horizontal swiping handled on end
                    }
                }
                .onEnded { value in
                    if gestureDirection == .vertical {
                        if dismissOffset.height > 150 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dismissOffset = .zero
                            }
                        }
                    } else if gestureDirection == .horizontal {
                        let threshold: CGFloat = 60
                        if value.translation.width < -threshold {
                            slideDirection = .trailing
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.advance()
                            }
                        } else if value.translation.width > threshold {
                            slideDirection = .leading
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.goBack()
                            }
                        }
                    }
                    gestureDirection = nil
                }
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPlaying)
    }

    // MARK: - Photo Content

    private var photoContent: some View {
        ZStack {
            if let photo = viewModel.currentPhoto {
                CachedAsyncImage(url: URL(string: photo.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(kenBurnsScale)
                        .offset(kenBurnsOffset)
                        .clipped()
                } placeholder: {
                    ZStack {
                        Color.black
                        if let thumbUrl = photo.thumbnailUrl ?? photo.smallThumbnailUrl {
                            CachedAsyncImage(url: URL(string: thumbUrl)) { thumb in
                                thumb
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .blur(radius: 10)
                            } placeholder: {
                                ProgressView().tint(.white)
                            }
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                }
                .id(viewModel.currentIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection),
                    removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
                ))
                .animation(.easeInOut(duration: 0.35), value: viewModel.currentIndex)
                .onTapGesture {
                    viewModel.togglePlayPause()
                    HapticsManager.playImpact(style: .light)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 3) {
            ForEach(0..<viewModel.photos.count, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.3))

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: {
                                if i < viewModel.currentIndex {
                                    return geo.size.width
                                } else if i == viewModel.currentIndex {
                                    return geo.size.width * viewModel.segmentProgress
                                } else {
                                    return 0
                                }
                            }())
                    }
                }
                .frame(height: 3)
            }
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                HapticsManager.playImpact(style: .light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Speed control
            Menu {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Button {
                        viewModel.playbackSpeed = speed
                    } label: {
                        Label(speed.rawValue, systemImage: viewModel.playbackSpeed == speed ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            // Period filter
            Menu {
                ForEach(MemoryPeriod.allCases) { period in
                    Button {
                        viewModel.selectedPeriod = period
                    } label: {
                        HStack {
                            Text(period.rawValue)
                            if viewModel.selectedPeriod == period {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.selectedPeriod.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bottom Overlay

    private var bottomOverlay: some View {
        VStack(spacing: 0) {
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 250)
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                // Metadata
                if let photo = viewModel.currentPhoto {
                    VStack(alignment: .leading, spacing: 4) {
                        // Sender name or skeleton
                        let senderName: String? = viewModel.friendNameCache[photo.senderId]
                        if let name = senderName {
                            Text(name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 100, height: 16)
                                .shimmer()
                        }

                        HStack(spacing: 8) {
                            // Date
                            Text(formattedDate(photo.timestamp))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))

                            // City
                            if let city = photo.cityName, !city.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 10))
                                    Text(city)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }

                // Counter
                Text("\(viewModel.currentIndex + 1) / \(viewModel.photos.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                // Controls
                HStack(spacing: 32) {
                    // Play/Pause
                    Button {
                        HapticsManager.playImpact(style: .light)
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 52, height: 52)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    // Share
                    Button {
                        HapticsManager.playImpact(style: .medium)
                        Task {
                            shareImage = await viewModel.generateShareImage()
                            if shareImage != nil {
                                showShareSheet = true
                            }
                        }
                    } label: {
                        if viewModel.isGeneratingShare {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(viewModel.isGeneratingShare)
                }
                .padding(.bottom, 16)
            }
            .padding(.bottom, 24)
            .background(Color.black.opacity(0.9))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.2))

            Text(String(localized: "henüz anı yok"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))

            Text(String(localized: "arkadaşlarınla fotoğraf paylaştıkça\nanılar burada görünecek."))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text(String(localized: "geri dön"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func buildFriendNameCache() {
        var cache: [String: String] = [:]
        for friend in localFriends {
            if let name = friend.profile?.displayName ?? friend.profile?.username {
                cache[friend.userId] = name
            }
        }
        // Add current user
        if let myId = Auth.auth().currentUser?.uid {
            cache[myId] = String(localized: "sen")
        }
        viewModel.friendNameCache = cache
    }

    private func triggerKenBurns() {
        // Reset immediately without animation
        withAnimation(.none) {
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
        }
        // Reduce Motion: skip the slow zoom/pan entirely. The Ken Burns effect
        // is decorative — it doesn't carry meaning. With it off, the photo
        // simply sits at 1.0 scale, matching how stills present elsewhere.
        guard !reduceMotion else { return }
        // After a brief delay, start the slow Ken Burns movement
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            withAnimation(.easeInOut(duration: 5.0)) {
                kenBurnsScale = CGFloat.random(in: 1.05...1.12)
                kenBurnsOffset = CGSize(
                    width: CGFloat.random(in: -15...15),
                    height: CGFloat.random(in: -15...15)
                )
            }
        }
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
