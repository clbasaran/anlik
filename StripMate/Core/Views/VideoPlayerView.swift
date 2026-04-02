import SwiftUI
import AVKit

/// Reusable looping video player for strip clips.
public struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var isMuted: Bool

    public init(url: URL, startMuted: Bool = true) {
        self.url = url
        self._isMuted = State(initialValue: startMuted)
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
            }

            Button {
                isMuted.toggle()
                player?.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .onTapGesture {
            if player?.timeControlStatus == .playing {
                player?.pause()
            } else {
                player?.play()
            }
        }
        .onAppear {
            let avPlayer = AVPlayer(url: url)
            avPlayer.isMuted = isMuted
            avPlayer.play()
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }
            self.player = avPlayer
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
