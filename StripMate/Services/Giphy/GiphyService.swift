import Foundation

// MARK: - GIPHY Sticker Model

public struct GiphySticker: Identifiable, Sendable {
    public let id: String
    public let previewUrl: String  // fixed_height_small — picker grid
    public let originalUrl: String // original — saved to Firestore
    public let title: String
}

// MARK: - GIPHY REST API Service

public actor GiphyService {
    public static let shared = GiphyService()

    // TODO: Replace with your GIPHY API key from https://developers.giphy.com/
    private let apiKey = "gFftw3FuFBXmeWPC9x7N4fbXQFcYvnGL"
    private let baseUrl = "https://api.giphy.com/v1/stickers"
    private let session = URLSession.shared

    /// Search GIPHY stickers with a query.
    public func searchStickers(query: String, limit: Int = 30, offset: Int = 0) async throws -> [GiphySticker] {
        guard !query.isEmpty else { return try await trendingStickers(limit: limit) }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseUrl)/search?api_key=\(apiKey)&q=\(encoded)&limit=\(limit)&offset=\(offset)&rating=pg")!
        return try await fetch(url: url)
    }

    /// Fetch trending GIPHY stickers.
    public func trendingStickers(limit: Int = 30, offset: Int = 0) async throws -> [GiphySticker] {
        let url = URL(string: "\(baseUrl)/trending?api_key=\(apiKey)&limit=\(limit)&offset=\(offset)&rating=pg")!
        return try await fetch(url: url)
    }

    // MARK: - Private

    private func fetch(url: URL) async throws -> [GiphySticker] {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GiphyError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else {
            throw GiphyError.parseError
        }

        return dataArray.compactMap { item -> GiphySticker? in
            guard let id = item["id"] as? String,
                  let images = item["images"] as? [String: Any] else { return nil }

            // Preview: fixed_height_small for fast loading in grid
            let preview = images["fixed_height_small"] as? [String: Any]
            let previewUrl = preview?["url"] as? String ?? ""

            // Original: full quality for storing
            let original = images["original"] as? [String: Any]
            let originalUrl = original?["url"] as? String ?? ""

            guard !previewUrl.isEmpty, !originalUrl.isEmpty else { return nil }

            let title = item["title"] as? String ?? ""

            return GiphySticker(id: id, previewUrl: previewUrl, originalUrl: originalUrl, title: title)
        }
    }
}

// MARK: - Errors

public enum GiphyError: LocalizedError {
    case invalidResponse
    case parseError

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "GIPHY yanıt vermedi."
        case .parseError: return "GIPHY verileri okunamadı."
        }
    }
}
