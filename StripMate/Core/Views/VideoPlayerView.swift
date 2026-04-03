import SwiftUI
import AVFoundation

// MARK: - Video Cache

/// File-based cache for short video clips (max 5 seconds).
/// Eliminates buffering delay by serving videos from local disk after first download.
final class VideoCache: @unchecked Sendable {
    static let shared = VideoCache()

    private let cacheDir: URL
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100 MB
    private let queue = DispatchQueue(label: "com.stripmate.videocache")

    private init() {
        guard let baseDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("video_cache", isDirectory: true)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            return
        }
        let dir = baseDir.appendingPathComponent("video_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheDir = dir
    }

    func localURL(for remoteURL: URL) -> URL {
        let filename = remoteURL.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(80)
        return cacheDir.appendingPathComponent(String(filename) + ".mp4")
    }

    func cachedFile(for remoteURL: URL) -> URL? {
        let local = localURL(for: remoteURL)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    func download(_ remoteURL: URL) async -> URL? {
        if let cached = cachedFile(for: remoteURL) { return cached }

        let local = localURL(for: remoteURL)
        do {
            let (tmpFile, response) = try await URLSession.shared.download(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            try? FileManager.default.removeItem(at: local)
            try FileManager.default.moveItem(at: tmpFile, to: local)
            queue.async { self.trimIfNeeded() }
            return local
        } catch {
            return nil
        }
    }

    private func trimIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]) else { return }

        var totalSize = 0
        var entries: [(url: URL, date: Date, size: Int)] = []
        for file in files {
            let values = try? file.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey])
            let size = values?.fileSize ?? 0
            let date = values?.contentAccessDate ?? Date.distantPast
            totalSize += size
            entries.append((url: file, date: date, size: size))
        }

        guard totalSize > maxCacheSize else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries {
            try? FileManager.default.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= maxCacheSize / 2 { break }
        }
    }
}

// MARK: - AVPlayerLayer UIView (no AVPlayerViewController = no preroll crash)

/// Uses AVPlayerLayer directly instead of AVPlayerViewController.
/// This avoids the SIGABRT in -[AVPlayer prerollAtRate:completionHandler:]
/// that occurs when SwiftUI's VideoPlayer is laid out during sheet transitions.
private final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func setPlayer(_ player: AVPlayer?) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }
}

private struct PlayerLayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.setPlayer(player)
    }
}

// MARK: - Video Player View

/// Reusable looping video player for strip clips.
/// Uses AVPlayerLayer directly (not SwiftUI VideoPlayer) to avoid crashes during sheet transitions.
/// Pre-downloads short videos to local cache for instant playback.
public struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var isMuted: Bool
    @State private var loopObserver: NSObjectProtocol?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var errorObserver: NSKeyValueObservation?
    @State private var isVisible = false
    @State private var isLoading = true
    @State private var hasFailed = false

    public init(url: URL, startMuted: Bool = true) {
        self.url = url
        self._isMuted = State(initialValue: startMuted)
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // AVPlayerLayer-based view — safe during sheet transitions
            PlayerLayerRepresentable(player: player)

            if isLoading && !hasFailed {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if hasFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(localized: "Video yuklenemedi"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .contentShape(Rectangle())
        .onTapGesture {
            guard let player, !hasFailed else { return }
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
        .task {
            isVisible = true
            await setupPlayer()
        }
        .onDisappear {
            teardown()
        }
    }

    // MARK: - Setup & Teardown

    private func setupPlayer() async {
        // Resolve playback URL (prefer local cache)
        let playbackURL: URL
        if let cached = VideoCache.shared.cachedFile(for: url) {
            playbackURL = cached
        } else {
            // Stream from remote; download in background for next time
            playbackURL = url
            Task.detached(priority: .utility) {
                _ = await VideoCache.shared.download(url)
            }
        }

        let item = AVPlayerItem(url: playbackURL)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.isMuted = isMuted
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        item.preferredForwardBufferDuration = 10

        // Observe readyToPlay before assigning player
        let observation = item.observe(\.status, options: [.initial, .new]) { observedItem, _ in
            Task { @MainActor in
                guard isVisible else { return }
                switch observedItem.status {
                case .readyToPlay:
                    isLoading = false
                    avPlayer.play()
                case .failed:
                    isLoading = false
                    hasFailed = true
                    #if DEBUG
                    print("DEBUG: AVPlayerItem failed: \(observedItem.error?.localizedDescription ?? "unknown")")
                    #endif
                default:
                    break
                }
            }
        }
        statusObserver = observation

        // Loop on end
        let loopObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
        loopObserver = loopObs

        // Only now expose the player to the view (triggers PlayerLayerRepresentable update)
        self.player = avPlayer
    }

    private func teardown() {
        isVisible = false
        statusObserver?.invalidate()
        statusObserver = nil
        errorObserver?.invalidate()
        errorObserver = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        loopObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
