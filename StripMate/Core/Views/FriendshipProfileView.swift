import SwiftUI
import SwiftData
import FirebaseAuth

struct FriendshipProfileView: View {
    let friendId: String
    let friendProfile: UserProfile
    /// Where this profile was opened from (forwarded to ProfileVisitsService).
    var visitSource: ProfileVisitSource = .list

    @Query(sort: \Strip.timestamp, order: .reverse) private var allStrips: [Strip]
    @State private var viewModel: FriendshipProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var chartAppeared = false
    @State private var activeTooltip: String? = nil

    private let tooltipExplanations: [String: String] = [
        "ilk foto": String(localized: "arkadaşlığınızın ilk fotoğrafı"),
        "toplam foto": String(localized: "toplam paylaşılan foto sayısı"),
        "en aktif gün": String(localized: "en çok foto paylaştığınız gün"),
        "mevcut bağ": String(localized: "aralıksız paylaşım bağı"),
        "en uzun bağ": String(localized: "en uzun foto bağı"),
        "gönderilen": String(localized: "senin gönderdiğin"),
        "alınan": String(localized: "arkadaşının gönderdiği")
    ]

    init(friendId: String, friendProfile: UserProfile, visitSource: ProfileVisitSource = .list) {
        self.friendId = friendId
        self.friendProfile = friendProfile
        self.visitSource = visitSource
        self._viewModel = State(initialValue: FriendshipProfileViewModel(friendId: friendId, friendProfile: friendProfile))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                skeletonView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Back button
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Header
                        friendshipHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(Brand.Animations.bouncy, value: appeared)

                        // Stats
                        statsCardsSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(Brand.Animations.bouncy.delay(0.1), value: appeared)

                        // Chart
                        monthlyChartSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(Brand.Animations.bouncy.delay(0.2), value: appeared)

                        // Grid
                        sharedMomentsSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(Brand.Animations.bouncy.delay(0.3), value: appeared)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData(allStrips: allStrips)
            withAnimation {
                appeared = true
            }
            // Visit log for the automation engine — self-visit + throttle + block
            // filters live inside the service.
            let viewerId = Auth.auth().currentUser?.uid ?? ""
            await ProfileVisitsService.shared.recordVisit(
                visitorId: viewerId,
                profileId: friendId,
                source: visitSource
            )
        }
        .onChange(of: activeTooltip) { _, newValue in
            if newValue != nil {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        activeTooltip = nil
                    }
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(spacing: 24) {
            // Header skeleton
            HStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 60, height: 60)
                Spacer()
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 60, height: 60)
            }
            .padding(.horizontal, 32)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 2)
            )
            .shimmer()

            // Stats skeleton
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 130, height: 90)
                }
            }
            .padding(.horizontal, 20)
            .shimmer()

            // Chart skeleton
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 200)
                .padding(.horizontal, 20)
                .shimmer()

            // Grid skeleton
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ], spacing: 2) {
                ForEach(0..<9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(.horizontal, 20)
            .shimmer()

            Spacer()
        }
        .padding(.top, 60)
    }

    // MARK: - Header

    private var friendshipHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                avatarCircle(
                    url: viewModel.currentUserProfile?.avatarUrl,
                    fallback: viewModel.currentUserProfile?.displayName ?? "?"
                )

                // Connection line with gradient
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.1),
                                    .white.opacity(0.35),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)

                    if let streak = viewModel.streak {
                        HStack(spacing: 4) {
                            Image(systemName: streak.tier.tierIcon)
                                .font(.system(size: 11, weight: .medium))
                            Text(streak.tier.tierName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)

                avatarCircle(
                    url: friendProfile.avatarUrl,
                    fallback: friendProfile.displayName ?? "?"
                )
            }
            .padding(.horizontal, 32)

            // Usernames
            HStack {
                Text("@\(viewModel.currentUserProfile?.username ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text("@\(friendProfile.username ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 32)
        }
    }

    private func avatarCircle(url: String?, fallback: String) -> some View {
        Group {
            if let avatarUrl = url, let imageUrl = URL(string: avatarUrl) {
                CachedAsyncImage(url: imageUrl) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder(fallback: fallback)
                }
            } else {
                avatarPlaceholder(fallback: fallback)
            }
        }
    }

    private func avatarPlaceholder(fallback: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 64, height: 64)
            .overlay(
                Text(String(fallback.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Stats Cards

    private var statsCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(
                    title: String(localized: "ilk foto"),
                    value: firstPhotoFormatted,
                    icon: "calendar",
                    tooltipKey: "ilk foto"
                )
                statCard(
                    title: String(localized: "toplam foto"),
                    value: "\(viewModel.totalPhotos)",
                    icon: "photo.stack",
                    tooltipKey: "toplam foto"
                )
                statCard(
                    title: String(localized: "gönderilen"),
                    value: "\(viewModel.sentPhotos)",
                    icon: "arrow.up.circle",
                    tooltipKey: "gönderilen"
                )
                statCard(
                    title: String(localized: "alınan"),
                    value: "\(viewModel.receivedPhotos)",
                    icon: "arrow.down.circle",
                    tooltipKey: "alınan"
                )
                statCard(
                    title: String(localized: "en aktif gün"),
                    value: viewModel.mostActiveDay,
                    icon: "chart.bar.fill",
                    tooltipKey: "en aktif gün"
                )
                statCard(
                    title: String(localized: "mevcut bağ"),
                    value: "\(viewModel.currentStreak)",
                    icon: "flame.fill",
                    tooltipKey: "mevcut bağ"
                )
                statCard(
                    title: String(localized: "en uzun bağ"),
                    value: "\(viewModel.longestStreak)",
                    icon: "trophy.fill",
                    tooltipKey: "en uzun bağ"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private var firstPhotoFormatted: String {
        guard let date = viewModel.firstPhotoDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }

    private func statCard(title: String, value: String, icon: String, tooltipKey: String) -> some View {
        Button {
            HapticsManager.playImpact(style: .light)
            withAnimation(Brand.Animations.tap) {
                activeTooltip = tooltipKey
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(width: 130, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .overlay(alignment: .top) {
            if activeTooltip == tooltipKey, let explanation = tooltipExplanations[tooltipKey] {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    .offset(y: -40)
            }
        }
    }

    // MARK: - Monthly Activity Chart

    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "aylik aktivite"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 20)

            let maxCount = viewModel.monthlyActivity.map(\.count).max() ?? 1

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(viewModel.monthlyActivity.enumerated()), id: \.offset) { i, item in
                    VStack(spacing: 6) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        let normalizedHeight = maxCount > 0
                            ? CGFloat(item.count) / CGFloat(maxCount)
                            : 0
                        let targetHeight = max(4, 120 * normalizedHeight)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(item.count > 0 ? 0.15 + (0.65 * normalizedHeight) : 0.05))
                            .frame(height: chartAppeared ? targetHeight : 4)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.08),
                                value: chartAppeared
                            )

                        Text(item.month)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .onAppear {
                chartAppeared = true
            }
        }
    }

    // MARK: - Shared Moments Grid

    private var sharedMomentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "paylaşılan anlar"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                if !viewModel.sharedPhotos.isEmpty {
                    Text("\(viewModel.sharedPhotos.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 20)

            if viewModel.sharedPhotos.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle",
                    title: String(localized: "henüz paylaşılan an yok"),
                    subtitle: String(localized: "bir foto gönder ve burada görünsün.")
                )
            } else {
                let currentUserId = Auth.auth().currentUser?.uid ?? ""

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(viewModel.displayedPhotos, id: \.id) { strip in
                        let locked = strip.isLockedFor(currentUserId)
                        NavigationLink {
                            PhotoDetailView(
                                photo: strip.asMetadata,
                                isSentByMe: strip.senderId == currentUserId,
                                onDelete: nil
                            )
                        } label: {
                            ZStack {
                                CachedAsyncImage(url: URL(string: strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl)) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.04))
                                        .aspectRatio(1, contentMode: .fill)
                                }
                                .blur(radius: locked ? 30 : 0)

                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticsManager.playImpact(style: .light)
                        })
                    }

                    // Pagination trigger
                    if viewModel.hasMorePhotos {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                viewModel.loadMorePhotos()
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
