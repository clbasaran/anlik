import SwiftUI
import FirebaseAuth

// MARK: - Sayfa 1: Başlık Kartı

struct RecapTitlePage: View {
    let summary: RollcallSummary
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Bulanık arka plan fotoğraf
            if let url = summary.highlightPhotoUrl.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 30)
                        .opacity(0.15)
                } placeholder: { Color.clear }
                .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                Spacer()

                Text("Hafta \(summary.weekNumber)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                Text("\(summary.startDate.formatted(.dateTime.day().month())) – \(summary.endDate.formatted(.dateTime.day().month()))")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                Text("anlık.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 8)
                    .opacity(showContent ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(Brand.Animations.fadeOutLong.delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Sayfa 2: Fotoğraf Sayısı + Trend

struct RecapPhotoCountPage: View {
    let summary: RollcallSummary
    @State private var displayedCount = 0
    @State private var showTrend = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Dev sayı
            Text("\(displayedCount)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Text("an bu hafta")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))

            // Gönderilen / Alınan pill'ler
            HStack(spacing: 12) {
                Label("\(summary.sentCount) gönderilen", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())

                Label("\(summary.receivedCount) alınan", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            // Trend
            if showTrend {
                HStack(spacing: 6) {
                    Image(systemName: summary.trend.icon)
                        .foregroundColor(summary.trend.isPositive ? .white.opacity(0.8) : .white.opacity(0.5))
                    Text(summary.trend.description)
                        .foregroundColor(.white.opacity(0.6))
                }
                .font(.subheadline)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .onAppear {
            animateCount()
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    withAnimation(Brand.Animations.fadeOutSlow) {
                        showTrend = true
                    }
                }
            }
        }
    }

    private func animateCount() {
        let target = summary.photosCount
        let steps = min(target, 30)
        guard steps > 0 else { displayedCount = 0; return }
        let interval = 0.8 / Double(steps)

        Task {
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                await MainActor.run {
                    withAnimation(.spring(response: 0.2)) {
                        displayedCount = Int(Double(target) * Double(i) / Double(steps))
                    }
                }
            }
        }
    }
}

// MARK: - Sayfa 3: En İyi Arkadaş

struct RecapTopFriendPage: View {
    let summary: RollcallSummary
    @State private var showContent = false
    @State private var avatarUrl: String?
    @State private var friendName: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Üst etiket
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                Text("EN ÇOK PAYLAŞTIĞIN KİŞİ")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundColor(.white.opacity(0.4))
            .opacity(showContent ? 1 : 0)

            // Avatar
            ZStack {
                // Dış halka
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 130, height: 130)

                if let urlString = avatarUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } placeholder: {
                        avatarPlaceholder
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .scaleEffect(showContent ? 1 : 0.3)
            .opacity(showContent ? 1 : 0)

            // İsim
            Text(friendName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

            // Fotoğraf sayısı badge
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 14))
                Text("\(summary.topFriendPhotoCount) an paylaştınız")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: Capsule())
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)

            // Toplam arkadaş bilgisi
            if summary.friendsInteractedCount > 1 {
                Text("bu hafta \(summary.friendsInteractedCount) arkadaşınla etkileştin")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 4)
                    .opacity(showContent ? 1 : 0)
            }

            Spacer()
        }
        .onAppear {
            friendName = summary.topFriendDisplayName ?? "Arkadaşın"
            loadFriendAvatar()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) {
                showContent = true
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(
                Text(String(friendName.prefix(1)).uppercased())
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            )
    }

    private func loadFriendAvatar() {
        guard let friendId = summary.topFriendId else { return }
        Task {
            do {
                let profile = try await DependencyContainer.shared.userRepository.fetchProfile(for: friendId)
                await MainActor.run {
                    self.avatarUrl = profile.avatarUrl
                    if let name = profile.displayName, !name.isEmpty {
                        self.friendName = name
                    }
                }
            } catch {
                AppLogger.ui.error("Failed to load friend avatar for \(friendId): \(error.localizedDescription, privacy: .public)")
                // Fallback: keep the placeholder avatar and default name
            }
        }
    }
}

// MARK: - Sayfa 4: Şehirler

struct RecapCitiesPage: View {
    let summary: RollcallSummary
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.8))
                .scaleEffect(showContent ? 1 : 0.3)

            Text("\(summary.uniqueCities.count)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("farklı şehirden paylaşıldı")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))

            // Şehir chip'leri
            FlowLayout(spacing: 8) {
                ForEach(summary.uniqueCities, id: \.self) { city in
                    Text(city)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Sayfa 5: Zaman Kalıpları

struct RecapTimePatternsPage: View {
    let summary: RollcallSummary
    @State private var showBars = false

    private var maxCount: Int {
        max(summary.timeDistribution.morning, summary.timeDistribution.afternoon,
            summary.timeDistribution.evening, summary.timeDistribution.night, 1)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("paylaşım saatlerin")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            VStack(spacing: 16) {
                timeBar(icon: "sun.horizon.fill", label: "Sabah", count: summary.timeDistribution.morning)
                timeBar(icon: "sun.max.fill", label: "Öğle", count: summary.timeDistribution.afternoon)
                timeBar(icon: "sunset.fill", label: "Akşam", count: summary.timeDistribution.evening)
                timeBar(icon: "moon.stars.fill", label: "Gece", count: summary.timeDistribution.night)
            }
            .padding(.horizontal, 32)

            // Dominant period
            VStack(spacing: 4) {
                if !summary.timeDistribution.dominantPeriod.isEmpty {
                    Text("en çok \(summary.timeDistribution.dominantPeriod) paylaşıyorsun")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                if let dayName = summary.mostActiveDayName {
                    Text("\(dayName) en aktif günün")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .opacity(showBars ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8).delay(0.3)) {
                showBars = true
            }
        }
    }

    private func timeBar(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.white.opacity(0.7))

            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(count == maxCount ? 0.8 : 0.4))
                            .frame(width: showBars ? geo.size.width * CGFloat(count) / CGFloat(maxCount) : 0)
                    }
            }
            .frame(height: 12)

            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Sayfa 6: Seri Öne Çıkanları

struct RecapStreaksPage: View {
    let summary: RollcallSummary
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.6))
                .scaleEffect(showContent ? 1 : 0.3)

            if !summary.streakMilestones.isEmpty {
                Text("bağ kilometre taşları")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                VStack(spacing: 12) {
                    ForEach(summary.streakMilestones) { milestone in
                        HStack {
                            Label("\(milestone.milestoneValue) gün", systemImage: "flame.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(milestone.friendDisplayName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
            } else {
                Text("en uzun aktif bağın")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("\(summary.longestActiveStreak) gün")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Sayfa 7: Fotoğraf Grid + Kapanış

struct RecapPhotoGridPage: View {
    let summary: RollcallSummary
    let strips: [Strip]
    @State private var showContent = false

    /// En popüler fotoğraflar: gizli anları hariç tut, en çok kişiyle paylaşılana göre sırala
    private var recentPhotos: [Strip] {
        let myId = FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
        return Array(
            strips.filter { !$0.isLockedFor(myId) }
            .sorted { a, b in
                let aScore = a.receiverIds.count
                let bScore = b.receiverIds.count
                if aScore != bScore { return aScore > bScore }
                return a.timestamp > b.timestamp
            }
            .prefix(6)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("haftanın öne çıkanları")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 60)

                // 2x3 grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(recentPhotos, id: \.id) { strip in
                        CachedAsyncImage(url: URL(string: strip.thumbnailUrl ?? strip.imageUrl)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 180)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Özet satırı
                HStack(spacing: 16) {
                    miniStat(icon: "photo.stack", value: "\(summary.photosCount)", label: "an")
                    miniStat(icon: "person.2", value: "\(summary.friendsInteractedCount)", label: "arkadaş")
                    miniStat(icon: "mappin", value: "\(summary.uniqueCities.count)", label: "şehir")
                }
                .padding(.top, 8)

                // Watermark
                Text("anlık.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(Brand.Animations.fadeOutSlow) {
                showContent = true
            }
        }
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - FlowLayout (Basit yatay sarmal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = max(totalHeight, y + rowHeight)
        }

        return (CGSize(width: maxWidth, height: totalHeight), offsets)
    }
}
