import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let eyebrow: String
    let title: String
    let description: String
}

public struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "onboarding_1",
            eyebrow: String(localized: "ilk an"),
            title: String(localized: "fotoğraf değil\nhafıza"),
            description: String(localized: "bugün sıradan gelen şey, yarın en sevdiğin anın olabilir.")
        ),
        OnboardingPage(
            image: "onboarding_2",
            eyebrow: String(localized: "yakın çevren"),
            title: String(localized: "kalabalık değil\nçevren"),
            description: String(localized: "çok kişi değil, iyi hissettiren insanlar yeter.")
        ),
        OnboardingPage(
            image: "onboarding_3",
            eyebrow: String(localized: "tepki değil bağ"),
            title: String(localized: "beğeni değil\nhis"),
            description: String(localized: "bazen tek bir cevap, bütün günü daha güzel yapar.")
        ),
        OnboardingPage(
            image: "onboarding_4",
            eyebrow: String(localized: "aynı anda"),
            title: String(localized: "konum değil\nbağ"),
            description: String(localized: "uzakta olsan da aynı anda yakın hissedebilirsin.")
        )
    ]

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // MARK: - Photo + Gradient per page
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    GeometryReader { geo in
                        ZStack {
                            // Full-bleed photo
                            Image(page.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()

                            // Top vignette
                            VStack(spacing: 0) {
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.7), location: 0),
                                        .init(color: .black.opacity(0.0), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 180)
                                Spacer()
                            }

                            // Bottom gradient
                            VStack(spacing: 0) {
                                Spacer()
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black.opacity(0.4), location: 0.3),
                                        .init(color: .black.opacity(0.85), location: 0.6),
                                        .init(color: .black, location: 0.8)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: geo.size.height * 0.5)
                            }

                            // Text content
                            VStack(alignment: .leading, spacing: 12) {
                                Spacer()

                                Text(page.eyebrow)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .textCase(.uppercase)
                                    .tracking(1.2)

                                Text(page.title)
                                    .font(.system(.largeTitle, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tracking(-0.5)

                                Text(page.description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .lineSpacing(4)

                                Spacer()
                                    .frame(height: geo.size.height * 0.25)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // MARK: - Fixed overlay (logo, dots, buttons)
            VStack(spacing: 0) {
                // Logo
                Text(Brand.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1)
                    .padding(.top, 64)

                Spacer()

                // Custom page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? .white : .white.opacity(0.25))
                            .frame(width: i == currentPage ? 28 : 8, height: 4)
                            .animation(.snappy(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Primary button
                Button {
                    HapticsManager.playImpact(style: .medium)
                    if currentPage == pages.count - 1 {
                        AnalyticsService.shared.log(.onboardingCompleted)
                        withAnimation(Brand.Animations.fadeSlow) { hasSeenOnboarding = true }
                    } else {
                        withAnimation(Brand.Animations.fadeSlow) { currentPage += 1 }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? String(localized: "başla") : String(localized: "devam et"))
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(currentPage == pages.count - 1 ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(currentPage == pages.count - 1 ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(.white.opacity(currentPage == pages.count - 1 ? 0 : 0.15), lineWidth: 0.5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 28)
                .animation(Brand.Animations.fadeStandard, value: currentPage)
                .accessibilityLabel(currentPage == pages.count - 1 ? String(localized: "uygulamayı başlat") : String(localized: "sonraki sayfa"))

                // Skip
                Button {
                    AnalyticsService.shared.log(.onboardingSkipped, parameters: ["at_page": currentPage])
                    withAnimation(Brand.Animations.fadeSlow) { hasSeenOnboarding = true }
                } label: {
                    Text(String(localized: "atla"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(currentPage == pages.count - 1 ? 0 : 0.4))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(currentPage == pages.count - 1)
                .padding(.top, 14)
                .padding(.bottom, 48)
                .accessibilityLabel(String(localized: "karşılama ekranını atla"))
            }
        }
    }
}
