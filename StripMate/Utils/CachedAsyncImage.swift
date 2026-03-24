import SwiftUI

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    
    public init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    public var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }
    
    private var cacheTTL: TimeInterval { 24 * 60 * 60 } // 24 hours
    
    private func load() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }
        
        let request = URLRequest(url: url)
        
        // Check local disk cache with TTL validation
        if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
            let cacheAge = cachedResponse.userInfo?["cacheDate"] as? Date ?? Date.distantPast
            let isExpired = Date().timeIntervalSince(cacheAge) > cacheTTL
            
            if !isExpired, let uiImage = UIImage(data: cachedResponse.data) {
                // Cache already stores orientation-corrected JPEG — no re-processing needed
                phase = .success(Image(uiImage: uiImage))
                return
            } else if isExpired {
                URLCache.shared.removeCachedResponse(for: request)
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
               let image = UIImage.orientationCorrectedImage(from: data) {
                // Store orientation-corrected JPEG so future cache hits skip CGImageSource processing
                let correctedData = image.jpegData(compressionQuality: 0.9) ?? data
                let cachedData = CachedURLResponse(response: response, data: correctedData, userInfo: ["cacheDate": Date()], storagePolicy: .allowed)
                URLCache.shared.storeCachedResponse(cachedData, for: request)
                
                phase = .success(Image(uiImage: image))
            } else {
                phase = .failure(URLError(.badServerResponse))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
