import SwiftUI

// MARK: - App Tour — Live Interactive Experience

public struct AppTourView: View {
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @State private var currentStep = 0

    // Two steps only: capture/send and the friend code. Both feed directly
    // into what the user does next (the friend gate + first photo). Widget
    // and watch education moved out of first-run — they belong at moments
    // the user can act on them.
    private let totalSteps = 2

    private var isLastStep: Bool { currentStep == totalSteps - 1 }

    private var titles: [String] {[
        String(localized: "fotoğraf çek, gönder"),
        String(localized: "en yakınlarını ekle")
    ]}

    private var descriptions: [String] {[
        String(localized: "kamerayı aç, anını yakala ve arkadaşlarına gönder."),
        String(localized: "arkadaş kodunu paylaş, sadece senin insanların burada.")
    ]}

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(Brand.name)
                        .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .tracking(-1)
                    Spacer()
                    Text("\(currentStep + 1)/\(totalSteps)")
                        .font(Brand.scaledFont(size: 13, weight: .medium, design: .monospaced, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 8)

                ZStack {
                    switch currentStep {
                    case 0: CameraDemoView()
                    case 1: FriendsDemoView()
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 370)
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer().frame(height: 8)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(titles[currentStep])
                        .font(Brand.scaledFont(size: 28, weight: .bold, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .tracking(-0.3)

                    Text(descriptions[currentStep])
                        .font(Brand.scaledFont(size: 15, weight: .regular, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer().frame(height: 20)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                        Capsule().fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 3)
                            .animation(Brand.Animations.fadeLong, value: currentStep)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Button {
                    HapticsManager.playImpact(style: .medium)
                    if isLastStep {
                        AnalyticsService.shared.log(.appTourCompleted)
                        withAnimation(Brand.Animations.fadeSlow) { hasSeenAppTour = true }
                    } else {
                        withAnimation(Brand.Animations.fadeLong) { currentStep += 1 }
                    }
                } label: {
                    Text(isLastStep ? String(localized: "hazırım") : String(localized: "devam et"))
                        .font(Brand.scaledFont(size: 17, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(isLastStep ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isLastStep ? Color.white : Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .animation(Brand.Animations.fadeStandard, value: currentStep)

                Button {
                    AnalyticsService.shared.log(.appTourSkipped, parameters: ["at_step": currentStep])
                    withAnimation(Brand.Animations.fadeSlow) { hasSeenAppTour = true }
                } label: {
                    Text(String(localized: "atla"))
                        .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(isLastStep ? 0 : 0.3))
                }
                .disabled(isLastStep)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}

// MARK: - Step 1: Camera Demo

private struct CameraDemoView: View {
    @State private var shutterScale: CGFloat = 1
    @State private var flashOpacity: Double = 0
    @State private var showSent = false
    @State private var showPhoto = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
                .overlay {
                    ZStack {
                        // Grid lines
                        VStack {
                            Spacer()
                            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
                            Spacer()
                            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            Rectangle().fill(.white.opacity(0.06)).frame(width: 0.5)
                            Spacer()
                            Rectangle().fill(.white.opacity(0.06)).frame(width: 0.5)
                            Spacer()
                        }

                        // Captured photo
                        if showPhoto {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .overlay {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white.opacity(0.12))
                                }
                                .padding(16)
                                .transition(.scale(scale: 1.08).combined(with: .opacity))
                        }

                        // Flash
                        Color.white.opacity(flashOpacity)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        // Sent badge
                        if showSent {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark")
                                            .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                                        Text(String(localized: "gönderildi"))
                                            .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .padding(14)
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 24)

            // Shutter button
            VStack {
                Spacer()
                Circle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 3)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().fill(.white).padding(6).scaleEffect(shutterScale))
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.08)) { shutterScale = 0.82 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeInOut(duration: 0.04)) { flashOpacity = 0.7 }
            withAnimation(.easeInOut(duration: 0.08)) { shutterScale = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(Brand.Animations.fadeOutStandard) { flashOpacity = 0 }
            withAnimation(Brand.Animations.tap) { showPhoto = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showSent = true }
        }
    }
}

// MARK: - Step 2: Friends Demo

private struct FriendsDemoView: View {
    @State private var visibleCards: Int = 0
    @State private var acceptedIndex: Int? = nil

    private let friends = [
        ("E", "elif", "ELIF042"),
        ("A", "ahmet", "AHMT099"),
        ("S", "selin", "SELN017"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(friends.enumerated()), id: \.offset) { index, friend in
                if index < visibleCards {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(friend.0)
                                    .font(Brand.scaledFont(size: 17, weight: .semibold, relativeTo: .body))
                                    .foregroundStyle(.white.opacity(0.6))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.1)
                                .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(.white)
                            Text(friend.2)
                                .font(Brand.scaledFont(size: 12, weight: .medium, design: .monospaced, relativeTo: .caption))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        Spacer()
                        if acceptedIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                                .font(Brand.scaledFont(size: 22, relativeTo: .title3))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text(String(localized: "ekle"))
                                .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            Spacer().frame(height: 16)

            // Friend code area
            VStack(spacing: 10) {
                HStack {
                    Text(String(localized: "arkadaş kodun"))
                        .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("CELAL037")
                        .font(Brand.scaledFont(size: 18, weight: .bold, design: .monospaced, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .tracking(2)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                        Text(String(localized: "kopyala"))
                            .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .onAppear { animate() }
    }

    private func animate() {
        for i in 0..<friends.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35 + 0.3) {
                withAnimation(Brand.Animations.standard) { visibleCards = i + 1 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(Brand.Animations.tap) { acceptedIndex = 0 }
        }
    }
}
