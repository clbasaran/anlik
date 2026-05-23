import SwiftUI
import AVKit
import AVFoundation

/// Plays a profile loop video on auto-loop, muted, with a thumbnail poster
/// frame shown until the video is ready. Designed for compact display in
/// profile galleries — typically 110x140 pt.
public struct ProfileLoopPlayerView: View {
    let loop: ProfileLoop
    let cornerRadius: CGFloat
    let aspectRatio: CGFloat

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isReady = false

    public init(loop: ProfileLoop, cornerRadius: CGFloat = 14, aspectRatio: CGFloat = 3 / 4) {
        self.loop = loop
        self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        ZStack {
            // Thumbnail (visible until video starts)
            if let thumbUrl = loop.thumbnailUrl, let url = URL(string: thumbUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
                .opacity(isReady ? 0 : 1)
            } else {
                placeholder
                    .opacity(isReady ? 0 : 1)
            }

            // Video player
            if let player {
                LoopingVideoPlayer(player: player)
                    .opacity(isReady ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: isReady)
            }

            // Boomerang badge
            if loop.isBoomerang {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "infinity")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.4), in: Circle())
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task {
            await setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            looper = nil
            isReady = false
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.5))
        )
    }

    private func setupPlayer() async {
        guard let url = URL(string: loop.videoUrl) else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .advance

        // Configure audio session to playback so muted videos still play
        // even with silent switch on (matches Instagram behavior).
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        let looper = AVPlayerLooper(player: queue, templateItem: item)
        self.player = queue
        self.looper = looper

        // Wait for ready, then play
        for _ in 0..<30 where item.status != .readyToPlay && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        await MainActor.run {
            isReady = true
            queue.play()
        }
    }
}

// MARK: - UIKit-bridged player (no AVKit chrome)

private struct LoopingVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
