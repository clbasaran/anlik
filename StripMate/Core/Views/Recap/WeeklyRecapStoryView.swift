import SwiftUI
import UIKit
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
    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?

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

                    // Paylas butonu
                    Button {
                        isPaused = true
                        Task {
                            shareImage = await ShareCardRenderer.render(summary: summary)
                            if shareImage != nil {
                                isShareSheetPresented = true
                            }
                            isPaused = false
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 4)

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
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheetView(image: image, summary: summary)
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
            withAnimation(Brand.Animations.fadeSlow) {
                currentPage += 1
            }
        } else {
            dismiss()
        }
    }

    private func goToPreviousPage() {
        if currentPage > 0 {
            withAnimation(Brand.Animations.fadeSlow) {
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

// MARK: - Share Sheet (Paylasim Secenekleri)

/// Render edilmis kart gorseli icin paylasim secenekleri sunar.
private struct ShareSheetView: View {
    let image: UIImage
    let summary: RollcallSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Onizleme
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .white.opacity(0.05), radius: 20)
                    .padding(.horizontal, 32)

                // Paylasim butonlari
                VStack(spacing: 12) {
                    // Instagram Stories
                    Button {
                        ShareCardRenderer.shareToInstagramStories(image: image)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 20))
                            Text("Instagram Stories")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Genel paylasim
                    Button {
                        ShareCardRenderer.presentShareSheet(image: image)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                            Text("Diger Uygulamalar")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 24)
            .background(Brand.black.ignoresSafeArea())
            .navigationTitle("Paylas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
