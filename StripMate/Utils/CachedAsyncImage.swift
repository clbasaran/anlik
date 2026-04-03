import SwiftUI

/// In-memory image cache shared across all CachedAsyncImage instances.
/// Avoids JPEG deserialization from URLCache on repeated displays.
private let _imageMemoryCache: NSCache<NSURL, UIImage> = {
    let c = NSCache<NSURL, UIImage>()
    c.countLimit = 150
    c.totalCostLimit = 80 * 1024 * 1024 // 80 MB
    return c
}()

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var phase: AsyncImagePhase
    @State private var didLoad: Bool
    @State private var networkFetched = false

    public init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder

        // Check in-memory cache synchronously so the view never flickers
        // a placeholder when the image is already cached.
        if let url, let cached = _imageMemoryCache.object(forKey: url as NSURL) {
            self._phase = State(initialValue: .success(Image(uiImage: cached)))
            self._didLoad = State(initialValue: true)
        } else {
            self._phase = State(initialValue: .empty)
            self._didLoad = State(initialValue: false)
        }
    }

    public var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case .success(let image):
                content(image)
                    .transition(.opacity.animation(.easeIn(duration: didLoad ? 0 : 0.2)))
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .task(id: url) {
            // Skip if already resolved from memory cache in init
            guard !didLoad else { return }
            await load()
        }
    }

    private var cacheTTL: TimeInterval { 24 * 60 * 60 } // 24 hours

    private func load() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }

        let nsurl = url as NSURL

        // 1. In-memory cache (instant, no deserialization)
        if let cached = _imageMemoryCache.object(forKey: nsurl) {
            didLoad = true
            phase = .success(Image(uiImage: cached))
            return
        }

        let request = URLRequest(url: url)

        // 2. Disk cache with TTL validation
        if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
            let cacheAge = cachedResponse.userInfo?["cacheDate"] as? Date ?? Date.distantPast
            let isExpired = Date().timeIntervalSince(cacheAge) > cacheTTL

            if !isExpired, let uiImage = UIImage(data: cachedResponse.data) {
                _imageMemoryCache.setObject(uiImage, forKey: nsurl, cost: cachedResponse.data.count)
                didLoad = true
                phase = .success(Image(uiImage: uiImage))
                return
            } else if isExpired {
                URLCache.shared.removeCachedResponse(for: request)
            }
        }

        // 3. Network fetch with fade-in
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
               let image = UIImage.orientationCorrectedImage(from: data) {
                let correctedData = image.jpegData(compressionQuality: 0.9) ?? data
                let cachedData = CachedURLResponse(response: response, data: correctedData, userInfo: ["cacheDate": Date()], storagePolicy: .allowed)
                URLCache.shared.storeCachedResponse(cachedData, for: request)
                _imageMemoryCache.setObject(image, forKey: nsurl, cost: correctedData.count)

                withAnimation(.easeIn(duration: 0.2)) {
                    phase = .success(Image(uiImage: image))
                }
            } else {
                phase = .failure(URLError(.badServerResponse))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
