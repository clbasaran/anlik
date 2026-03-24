import SwiftUI
import FirebaseAuth

/// Instagram Stories benzeri haftalık recap deneyimi.
/// Sayfa-sayfa swipe ile zengin içgörüler gösterir.
struct WeeklyRecapStoryView: View {
    let summary: RollcallSummary
    let strips: [Strip]
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    private let pageDuration: TimeInterval = 5.0

    /// Gösterilecek sayfalar (boş içerikli olanlar filtrelenir)
    private var pages: [RecapPage] {
        var result: [RecapPage] = []

        // 1. Başlık her zaman var
        result.append(.title)

        // 2. Fotoğraf sayısı + trend her zaman var
        result.append(.photoCount)

        // 3. Top friend (varsa)
        if summary.topFriendId != nil {
            result.append(.topFriend)
        }

        // 4. Şehirler (varsa)
        if !summary.uniqueCities.isEmpty {
            result.append(.cities)
        }

        // 5. Zaman kalıpları (en az 3 fotoğraf ve veri varsa anlamlı)
        if summary.photosCount >= 3, summary.timeDistribution.total > 0 {
            result.append(.timePatterns)
        }

        // 6. Seri öne çıkanları (aktif seri varsa)
        if summary.longestActiveStreak > 0 || !summary.streakMilestones.isEmpty {
            result.append(.streaks)
        }

        // 7. Fotoğraf grid her zaman var
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

            // Sol/sağ tap alanları
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
    private func pageContent(for page: RecapPage) -> some View {
        switch page {
        case .title:
            RecapTitlePage(summary: summary)
        case .photoCount:
            RecapPhotoCountPage(summary: summary)
        case .topFriend:
            RecapTopFriendPage(summary: summary)
        case .cities:
            RecapCitiesPage(summary: summary)
        case .timePatterns:
            RecapTimePatternsPage(summary: summary)
        case .streaks:
            RecapStreaksPage(summary: summary)
        case .photoGrid:
            RecapPhotoGridPage(summary: summary, strips: strips)
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
            return totalWidth // tamamlanmış
        } else if index == currentPage {
            return totalWidth * min(progress, 1.0) // aktif
        } else {
            return 0 // henüz gelmedi
        }
    }
}

// MARK: - Recap Page Enum

enum RecapPage {
    case title
    case photoCount
    case topFriend
    case cities
    case timePatterns
    case streaks
    case photoGrid
}
