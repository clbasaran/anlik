import SwiftUI

// MARK: - App Tour — Live Interactive Experience

public struct AppTourView: View {
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @State private var currentStep = 0

    private var titles: [String] {[
        String(localized: "fotoğraf çek, gönder"),
        String(localized: "en yakınlarını ekle"),
        String(localized: "anlarına geri dön"),
        String(localized: "widget'ını kur"),
        String(localized: "bilekten takip")
    ]}

    private var descriptions: [String] {[
        String(localized: "kamerayı aç, anını yakala ve arkadaşlarına gönder."),
        String(localized: "arkadaş kodunu paylaş, sadece senin insanların burada."),
        String(localized: "gönderdiğin ve aldığın tüm anlar burada kalır."),
        String(localized: "ana ekranına anlık. widget'ını ekle."),
        String(localized: "serilerini ve günlük görevini Apple Watch'tan takip et.")
    ]}

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(Brand.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-1)
                    Spacer()
                    Text("\(currentStep + 1)/5")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 8)

                ZStack {
                    switch currentStep {
                    case 0: CameraDemoView()
                    case 1: FriendsDemoView()
                    case 2: HistoryDemoView()
                    case 3: WidgetDemoView()
                    case 4: WatchDemoView()
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
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-0.3)

                    Text(descriptions[currentStep])
                        .font(.system(size: 15, weight: .regular))
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
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / 5, height: 3)
                            .animation(Brand.Animations.fadeLong, value: currentStep)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Button {
                    HapticsManager.playImpact(style: .medium)
                    if currentStep == 4 {
                        AnalyticsService.shared.log(.appTourCompleted)
                        withAnimation(Brand.Animations.fadeSlow) { hasSeenAppTour = true }
                    } else {
                        withAnimation(Brand.Animations.fadeLong) { currentStep += 1 }
                    }
                } label: {
                    Text(currentStep == 4 ? String(localized: "hazırım") : String(localized: "devam et"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(currentStep == 4 ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(currentStep == 4 ? Color.white : Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .animation(Brand.Animations.fadeStandard, value: currentStep)

                Button {
                    AnalyticsService.shared.log(.appTourSkipped, parameters: ["at_step": currentStep])
                    withAnimation(Brand.Animations.fadeSlow) { hasSeenAppTour = true }
                } label: {
                    Text(String(localized: "atla"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(currentStep == 4 ? 0 : 0.3))
                }
                .disabled(currentStep == 4)
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
                                            .font(.system(size: 11, weight: .bold))
                                        Text(String(localized: "gönderildi"))
                                            .font(.system(size: 13, weight: .semibold))
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
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.1)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(friend.2)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        Spacer()
                        if acceptedIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text(String(localized: "ekle"))
                                .font(.system(size: 14, weight: .semibold))
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("CELAL037")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(2)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(localized: "kopyala"))
                            .font(.system(size: 13, weight: .semibold))
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

// MARK: - Step 3: History Demo

private struct HistoryDemoView: View {
    @State private var visibleCount: Int = 0
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            // Date label
            HStack {
                Text(String(localized: "bugün"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(String(localized: "6 an"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<6, id: \.self) { index in
                    if index < visibleCount {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Circle().fill(.white.opacity(0.15)).frame(width: 12, height: 12)
                                        Spacer()
                                    }
                                    .padding(6)
                                }
                            }
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 12)

            // Stats bar
            HStack(spacing: 0) {
                statItem(value: "36", label: String(localized: "gönderilen"))
                Spacer()
                Rectangle().fill(.white.opacity(0.08)).frame(width: 0.5, height: 28)
                Spacer()
                statItem(value: "57", label: String(localized: "alınan"))
                Spacer()
                Rectangle().fill(.white.opacity(0.08)).frame(width: 0.5, height: 28)
                Spacer()
                statItem(value: "12", label: String(localized: "gün bağı"))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
        }
        .onAppear { animate() }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func animate() {
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12 + 0.2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { visibleCount = i + 1 }
            }
        }
    }
}

// MARK: - Step 4: Widget Demo

private struct WidgetDemoView: View {
    @State private var showWidget = false
    @State private var currentGuide = 0
    @State private var widgetScale: CGFloat = 0.85

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if !showWidget {
                    VStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 14) {
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.white.opacity(0.05))
                                        .frame(width: 50, height: 50)
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }

                if showWidget {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 220, height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .overlay {
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Text("anlık.")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .padding(.trailing, 14)
                                        .padding(.top, 12)
                                }
                                Spacer()
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.1))
                                Text(String(localized: "son an burada görünür"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.2))
                                Spacer()
                            }
                        }
                        .scaleEffect(widgetScale)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 10) {
                guideStep(n: 1, text: String(localized: "ana ekranda boş alana uzun bas"), active: currentGuide >= 1)
                guideStep(n: 2, text: String(localized: "sol üstteki + butonuna dokun"), active: currentGuide >= 2)
                guideStep(n: 3, text: String(localized: "anlık. widget'ını bul ve ekle"), active: currentGuide >= 3)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { animate() }
    }

    private func guideStep(n: Int, text: String, active: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? .black : .white.opacity(0.25))
                .frame(width: 22, height: 22)
                .background(active ? Color.white : Color.white.opacity(0.06))
                .clipShape(Circle())
                .animation(Brand.Animations.fadeSlow, value: active)
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(active ? .white.opacity(0.6) : .white.opacity(0.15))
                .animation(Brand.Animations.fadeSlow, value: active)
        }
    }

    private func animate() {
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5 + 0.2) {
                withAnimation(Brand.Animations.fadeSlow) { currentGuide = i }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(Brand.Animations.bouncy) { showWidget = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) { widgetScale = 1.0 }
        }
    }
}

// MARK: - Step 5: Apple Watch Demo

private struct WatchDemoView: View {
    @State private var showWatch = false
    @State private var showStreak = false
    @State private var showTask = false
    @State private var showGlance = false
    @State private var pulseRing = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Watch body
                if showWatch {
                    ZStack {
                        // Watch case
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 170, height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            )
                            .overlay {
                                VStack(spacing: 10) {
                                    // Streak row
                                    if showStreak {
                                        HStack(spacing: 8) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.orange)
                                            Text(String(localized: "12 gün bağ"))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }

                                    // Daily task
                                    if showTask {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.green)
                                            Text(String(localized: "günlük görev"))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.6))
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }

                                    // Recent photo glance
                                    if showGlance {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: [.white.opacity(0.08), .white.opacity(0.03)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ))
                                            .frame(height: 52)
                                            .overlay {
                                                HStack(spacing: 8) {
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .fill(.white.opacity(0.1))
                                                        .frame(width: 36, height: 36)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 12))
                                                                .foregroundStyle(.white.opacity(0.2))
                                                        )
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("elif")
                                                            .font(.system(size: 11, weight: .semibold))
                                                            .foregroundStyle(.white.opacity(0.7))
                                                        Text(String(localized: "az önce"))
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundStyle(.white.opacity(0.25))
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 8)
                                            }
                                            .padding(.horizontal, 16)
                                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                                    }
                                }
                                .padding(.vertical, 20)
                            }

                        // Digital crown
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 6, height: 24)
                            .offset(x: 88, y: -20)

                        // Pulse ring
                        if pulseRing {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 2)
                                .frame(width: 190, height: 220)
                                .scaleEffect(pulseRing ? 1.08 : 1.0)
                                .opacity(pulseRing ? 0 : 0.5)
                                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseRing)
                        }
                    }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .frame(height: 220)

            // Band straps hint
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                Text(String(localized: "Apple Watch ile her an bilgilen"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showWatch = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(Brand.Animations.standard) { showStreak = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(Brand.Animations.standard) { showTask = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showGlance = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            pulseRing = true
        }
    }
}
