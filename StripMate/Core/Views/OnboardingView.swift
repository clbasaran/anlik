import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
}

public struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "onboarding_1",
            title: "fotoğraf değil\nhafıza",
            description: "anlar uçar, sen yakala"
        ),
        OnboardingPage(
            image: "onboarding_2",
            title: "kalabalık değil\nçevren",
            description: "binlerce takipçi değil, gerçek insanlar"
        ),
        OnboardingPage(
            image: "onboarding_3",
            title: "beğeni değil\nhis",
            description: "kalp at, güldür, yaz, orada ol"
        ),
        OnboardingPage(
            image: "onboarding_4",
            title: "konum değil\nbağ",
            description: "nerede olursan ol, aynı anda burada"
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

                                Text(page.title)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tracking(-0.5)

                                Text(page.description)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.55))
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
                        withAnimation(.easeInOut(duration: 0.3)) { hasSeenOnboarding = true }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "başla" : "devam et")
                        .font(.system(size: 17, weight: .semibold))
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
                .animation(.easeInOut(duration: 0.25), value: currentPage)
                .accessibilityLabel(currentPage == pages.count - 1 ? "uygulamayı başlat" : "sonraki sayfa")

                // Skip
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { hasSeenOnboarding = true }
                } label: {
                    Text("atla")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(currentPage == pages.count - 1 ? 0 : 0.4))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(currentPage == pages.count - 1)
                .padding(.top, 14)
                .padding(.bottom, 48)
                .accessibilityLabel("karşılama ekranını atla")
            }
        }
    }
}
