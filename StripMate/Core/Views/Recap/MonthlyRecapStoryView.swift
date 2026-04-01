import SwiftUI
import FirebaseAuth

/// Instagram Stories benzeri aylık recap deneyimi.
/// 5 sayfa ile ayın özetini gösterir.
struct MonthlyRecapStoryView: View {
    let summary: MonthlySummary
    let strips: [Strip]
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    private let pageDuration: TimeInterval = 5.0

    /// Gösterilecek sayfalar (boş içerikli olanlar filtrelenir)
    private var pages: [MonthlyRecapPage] {
        var result: [MonthlyRecapPage] = []

        // 1. Başlık her zaman var
        result.append(.title)

        // 2. Haftalık bar chart (en az 2 hafta verisi varsa anlamlı)
        if summary.weeklyBreakdown.count >= 2 {
            result.append(.weeklyChart)
        }

        // 3. Top friend (varsa)
        if summary.topFriendId != nil {
            result.append(.topFriend)
        }

        // 4. Şehirler (varsa)
        if !summary.uniqueCities.isEmpty {
            result.append(.cities)
        }

        // 5. Fotoğraf grid her zaman var
        result.append(.photoGrid)

        return result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Sayfa içeriği
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageContent(for: page)
                        .tag(index)
                        .contentShape(Rectangle())
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Üstteki progress bar + kapatma butonu
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                                }
                        }
                        .frame(height: 2.5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 4)
                }

                Spacer()
            }

            // Sol/sağ tap alanları (üst butonları kapatmaz)
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goToPreviousPage() }
                    .frame(maxWidth: .infinity)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goToNextPage() }
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 80) // Progress bar + butonları açık bırak
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: currentPage) { _, _ in
            resetTimer()
        }
        .statusBarHidden()
    }

    // MARK: - Page Content

    @ViewBuilder
    private func pageContent(for page: MonthlyRecapPage) -> some View {
        switch page {
        case .title:
            MonthlyTitlePage(summary: summary)
        case .weeklyChart:
            MonthlyWeeklyChartPage(summary: summary)
        case .topFriend:
            MonthlyTopFriendPage(summary: summary)
        case .cities:
            MonthlyCitiesPage(summary: summary)
        case .photoGrid:
            MonthlyPhotoGridPage(summary: summary, strips: strips)
        }
    }

    // MARK: - Timer & Navigation

    private func startTimer() {
        timer?.invalidate()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isPaused else { return }
            progress += 0.05 / pageDuration
            if progress >= 1.0 {
                goToNextPage()
            }
        }
    }

    private func resetTimer() {
        progress = 0
    }

    private func goToNextPage() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            dismiss()
        }
    }

    private func goToPreviousPage() {
        if currentPage > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage -= 1
            }
        }
    }

    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentPage {
            return totalWidth
        } else if index == currentPage {
            return totalWidth * min(progress, 1.0)
        } else {
            return 0
        }
    }
}

// MARK: - Monthly Recap Page Enum

enum MonthlyRecapPage {
    case title
    case weeklyChart
    case topFriend
    case cities
    case photoGrid
}

// MARK: - Sayfa 1: Ay Başlığı

struct MonthlyTitlePage: View {
    let summary: MonthlySummary
    @State private var showContent = false
    @State private var displayedCount = 0

    var body: some View {
        ZStack {
            // Bulanık arka plan
            if let url = summary.thumbnailUrl.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 30)
                        .opacity(0.15)
                } placeholder: { Color.clear }
                .ignoresSafeArea()
            }

            VStack(spacing: 20) {
                Spacer()

                Text(summary.monthName)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                Text("\(summary.year)")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(showContent ? 1 : 0)

                // Dev fotoğraf sayısı
                Text("\(displayedCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .padding(.top, 16)

                Text("an bu ay")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)

                // Gönderilen / Alınan pill'ler
                HStack(spacing: 12) {
                    Label("\(summary.totalSent) gönderilen", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())

                    Label("\(summary.totalReceived) alınan", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .opacity(showContent ? 1 : 0)

                // Günlük ortalama
                Text("günde ortalama \(String(format: "%.1f", summary.averagePhotosPerDay)) an")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
                    .opacity(showContent ? 1 : 0)

                Text("anlık.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 8)
                    .opacity(showContent ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showContent = true
            }
            animateCount()
        }
    }

    private func animateCount() {
        let target = summary.totalPhotos
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

// MARK: - Sayfa 2: Haftalık Bar Chart

struct MonthlyWeeklyChartPage: View {
    let summary: MonthlySummary
    @State private var showBars = false

    private var maxWeekCount: Int {
        max(summary.weeklyBreakdown.max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("HAFTALIK AKTİVİTE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            // Bar chart
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(summary.weeklyBreakdown.enumerated()), id: \.offset) { index, count in
                    VStack(spacing: 8) {
                        Text("\(count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                count == maxWeekCount
                                    ? Color.white
                                    : Color.white.opacity(0.3)
                            )
                            .frame(
                                width: 40,
                                height: showBars ? max(CGFloat(count) / CGFloat(maxWeekCount) * 160, 8) : 8
                            )

                        Text("H\(index + 1)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(height: 220)

            // En aktif hafta bilgisi
            if let activeWeek = summary.mostActiveWeekNumber {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("en aktif hafta: Hafta \(activeWeek) (\(summary.mostActiveWeekCount) an)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(showBars ? 1 : 0)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                showBars = true
            }
        }
    }
}

// MARK: - Sayfa 3: Ayın En İyi Arkadaşı

struct MonthlyTopFriendPage: View {
    let summary: MonthlySummary
    @State private var showContent = false
    @State private var avatarUrl: String?
    @State private var friendName: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                Text("AYIN EN İYİ ARKADAŞI")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundColor(.white.opacity(0.4))
            .opacity(showContent ? 1 : 0)

            // Avatar
            ZStack {
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

            Text(friendName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

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

            if summary.uniqueFriendsCount > 1 {
                Text("bu ay \(summary.uniqueFriendsCount) arkadaşınla etkileştin")
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
            } catch { }
        }
    }
}

// MARK: - Sayfa 4: Ayın Şehirleri

struct MonthlyCitiesPage: View {
    let summary: MonthlySummary
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

// MARK: - Sayfa 5: Top 9 Fotoğraf Grid

struct MonthlyPhotoGridPage: View {
    let summary: MonthlySummary
    let strips: [Strip]
    @State private var showContent = false

    /// En popüler 9 fotoğraf
    private var topPhotos: [Strip] {
        Array(
            strips.sorted { a, b in
                let aScore = a.receiverIds.count
                let bScore = b.receiverIds.count
                if aScore != bScore { return aScore > bScore }
                return a.timestamp > b.timestamp
            }
            .prefix(9)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("\(summary.monthName) öne çıkanları")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 60)

                // 3x3 grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(topPhotos, id: \.id) { strip in
                        CachedAsyncImage(url: URL(string: strip.thumbnailUrl ?? strip.imageUrl)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 130)
                        }
                    }
                }
                .padding(.horizontal, 12)

                // Özet satırı
                HStack(spacing: 16) {
                    miniStat(icon: "photo.stack", value: "\(summary.totalPhotos)", label: "an")
                    miniStat(icon: "person.2", value: "\(summary.uniqueFriendsCount)", label: "arkadaş")
                    miniStat(icon: "mappin", value: "\(summary.uniqueCities.count)", label: "şehir")
                    miniStat(icon: "calendar", value: String(format: "%.1f", summary.averagePhotosPerDay), label: "gün/ort.")
                }
                .padding(.top, 8)

                Text("anlık.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
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
