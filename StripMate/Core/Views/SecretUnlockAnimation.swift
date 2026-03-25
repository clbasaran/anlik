import SwiftUI
import FirebaseAuth

/// Secret moment unlock: lock shakes → cracks → fragments fly → blur dissolves → chat screen appears
struct SecretUnlockAnimation: View {
    let photoUrl: String
    let strip: Strip

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .idle
    @State private var fragments: [Fragment] = []
    @State private var animationComplete = false

    private enum Phase: Equatable {
        case idle
        case shake
        case crack
        case shatter
        case reveal
    }

    var body: some View {
        ZStack {
            if animationComplete {
                // Animasyon bitti — direkt chat ekranı göster
                NavigationStack {
                    let photo = strip.asMetadata
                    let isMine = photo.senderId == Auth.auth().currentUser?.uid
                    PhotoDetailView(photo: photo, isSentByMe: isMine)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                            }
                        }
                }
                .transition(.opacity)
            } else {
                // Animasyon ekranı
                animationLayer
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            generateFragments()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                runSequence()
            }
        }
    }

    // MARK: - Animation Layer

    private var animationLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Fotoğraf — arkada, blur ile gizli
            CachedAsyncImage(url: URL(string: photoUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } placeholder: {
                Color(white: 0.05).ignoresSafeArea()
            }
            .blur(radius: phase == .reveal ? 0 : 30)
            .opacity(phase == .reveal ? 1.0 : (phase == .shatter ? 0.6 : 0.3))
            .scaleEffect(phase == .reveal ? 1.0 : 1.05)

            // Karartma
            Color.black
                .opacity(overlayOpacity)
                .ignoresSafeArea()

            // Kilit + parçalar
            ZStack {
                if phase != .shatter && phase != .reveal {
                    lockIcon
                }

                ForEach(fragments) { frag in
                    fragmentView(frag)
                }
            }
        }
    }

    // MARK: - Lock Icon

    private var lockIcon: some View {
        ZStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white.opacity(0.1))
                .blur(radius: 20)

            Image(systemName: "lock.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.3), radius: 8)
        }
        .scaleEffect(phase == .crack ? 1.1 : 1.0)
        .opacity(phase == .crack ? 0.8 : 1.0)
    }

    // MARK: - Fragments

    struct Fragment: Identifiable {
        let id = UUID()
        let symbol: String
        let angle: Double
        let distance: CGFloat
        let rotation: Double
        let size: CGFloat
        let delay: Double
    }

    private func generateFragments() {
        let symbols = ["lock.fill", "lock.open.fill", "key.fill", "diamond.fill", "triangle.fill", "square.fill", "circle.fill", "star.fill"]
        fragments = (0..<12).map { i in
            Fragment(
                symbol: symbols[i % symbols.count],
                angle: Double(i) * 30.0 + Double.random(in: -15...15),
                distance: CGFloat.random(in: 150...300),
                rotation: Double.random(in: -360...360),
                size: CGFloat.random(in: 8...18),
                delay: Double.random(in: 0...0.15)
            )
        }
    }

    @ViewBuilder
    private func fragmentView(_ frag: Fragment) -> some View {
        let radians = frag.angle * .pi / 180
        let isActive = phase == .shatter || phase == .reveal

        Image(systemName: frag.symbol)
            .font(.system(size: frag.size, weight: .bold))
            .foregroundStyle(.white.opacity(isActive ? 0 : 0.7))
            .offset(
                x: isActive ? cos(radians) * frag.distance : 0,
                y: isActive ? sin(radians) * frag.distance : 0
            )
            .rotationEffect(.degrees(isActive ? frag.rotation : 0))
            .scaleEffect(isActive ? 0.3 : 1.0)
            .animation(.easeOut(duration: 0.6).delay(frag.delay), value: isActive)
    }

    // MARK: - Computed

    private var overlayOpacity: Double {
        switch phase {
        case .idle, .shake: return 0.7
        case .crack: return 0.6
        case .shatter: return 0.3
        case .reveal: return 0
        }
    }

    // MARK: - Sequence

    private func runSequence() {
        // Titreme
        phase = .shake
        HapticsManager.playImpact(style: .light)
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                HapticsManager.playImpact(style: .light)
            }
        }

        // Çatlama
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) { phase = .crack }
            HapticsManager.playImpact(style: .medium)
        }

        // Parçalanma
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = .shatter }
            HapticsManager.playImpact(style: .heavy)
        }

        // Fotoğraf açılma
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.8)) { phase = .reveal }
            HapticsManager.playNotification(type: .success)
        }

        // Chat ekranına geç
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                animationComplete = true
            }
        }
    }
}
