import Foundation

struct SpotifyTrack: Identifiable {
    let id: String
    let name: String
    let artist: String
    let albumArtUrl: String?
}

/// Lightweight Spotify search using the public Web API with Client Credentials flow.
/// No user login required — only app-level access for search.
enum SpotifySearchService {
    // Spotify app credentials loaded from Secrets.plist (not committed to repo)
    private static let clientId: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict["SPOTIFY_CLIENT_ID"] as? String else {
            return ""
        }
        return value
    }()
    private static let clientSecret: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict["SPOTIFY_CLIENT_SECRET"] as? String else {
            return ""
        }
        return value
    }()

    private static var cachedToken: String?
    private static var tokenExpiry: Date?

    /// Search Spotify tracks by query. Returns up to 10 results.
    static func search(query: String) async -> [SpotifyTrack] {
        guard let token = await getAccessToken() else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=10&market=TR")
        else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tracks = (json?["tracks"] as? [String: Any])?["items"] as? [[String: Any]] ?? []

            return tracks.compactMap { item -> SpotifyTrack? in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }

                let artists = item["artists"] as? [[String: Any]] ?? []
                let artistName = artists.first?["name"] as? String ?? "Bilinmeyen"

                let album = item["album"] as? [String: Any]
                let images = album?["images"] as? [[String: Any]] ?? []
                // Use smallest image (last in array) for performance
                let artUrl = images.last?["url"] as? String ?? images.first?["url"] as? String

                return SpotifyTrack(id: id, name: name, artist: artistName, albumArtUrl: artUrl)
            }
        } catch {
            #if DEBUG
            print("Spotify search error: \(error)")
            #endif
            return []
        }
    }

    /// Get access token via Client Credentials flow (no user login needed)
    private static func getAccessToken() async -> String? {
        // Return cached token if still valid
        if let token = cachedToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return nil }

        let credentials = "\(clientId):\(clientSecret)"
        guard let credData = credentials.data(using: .utf8) else { return nil }
        let base64 = credData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let token = json?["access_token"] as? String else { return nil }
            let expiresIn = json?["expires_in"] as? Int ?? 3600

            cachedToken = token
            tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60)) // 1 min buffer
            return token
        } catch {
            #if DEBUG
            print("Spotify token error: \(error)")
            #endif
            return nil
        }
    }
}
