import Foundation
import Contacts
import CryptoKit
import FirebaseAuth

@Observable
final class ContactSyncService {

    enum SyncState {
        case idle, requestingPermission, loading, done, error(String)
    }

    struct MatchedContact: Identifiable {
        let id: String       // userId
        let displayName: String
        let username: String
        let avatarUrl: String
        let phoneNumber: String  // original normalized (for display / SMS invite)
    }

    struct UnmatchedContact: Identifiable {
        let id = UUID()
        let name: String
        let phoneNumber: String
    }

    var state: SyncState = .idle
    var matchedContacts: [MatchedContact] = []
    var unmatchedContacts: [UnmatchedContact] = []

    private let callableURL = "https://europe-west1-stripmate-app.cloudfunctions.net/matchContacts"

    func requestAndSync() async {
        state = .requestingPermission

        // Request contacts permission
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                state = .error("Rehber erişimi reddedildi")
                return
            }
        } catch {
            state = .error("Rehber erişim hatası")
            return
        }

        state = .loading

        // Fetch contacts
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        var rawContacts: [(name: String, phone: String, hash: String)] = []
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)

        do {
            try store.enumerateContacts(with: fetchRequest) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }

                for phone in contact.phoneNumbers {
                    let normalized = Self.normalizePhone(phone.value.stringValue)
                    guard !normalized.isEmpty else { continue }
                    let hash = Self.sha256(normalized)
                    rawContacts.append((name: name, phone: normalized, hash: hash))
                    break  // one number per contact
                }
            }
        } catch {
            state = .error("Rehber okunamadı")
            return
        }

        guard !rawContacts.isEmpty else {
            state = .done
            return
        }

        // Deduplicate by hash
        var seen = Set<String>()
        rawContacts = rawContacts.filter { seen.insert($0.hash).inserted }

        // Call Cloud Function via direct HTTPS
        let hashes = rawContacts.map { $0.hash }
        do {
            let matchesArray = try await callMatchContacts(phoneHashes: hashes)

            let matchedHashes = Set(matchesArray.compactMap { $0["hash"] as? String })

            matchedContacts = matchesArray.compactMap { m in
                guard let userId = m["userId"] as? String,
                      let hash = m["hash"] as? String,
                      let original = rawContacts.first(where: { $0.hash == hash }) else { return nil }
                return MatchedContact(
                    id: userId,
                    displayName: m["displayName"] as? String ?? "",
                    username: m["username"] as? String ?? "",
                    avatarUrl: m["avatarUrl"] as? String ?? "",
                    phoneNumber: original.phone
                )
            }

            unmatchedContacts = rawContacts
                .filter { !matchedHashes.contains($0.hash) }
                .map { UnmatchedContact(name: $0.name, phoneNumber: $0.phone) }

            state = .done
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Cloud Function Call (v2 callable protocol)

    private func callMatchContacts(phoneHashes: [String]) async throws -> [[String: Any]] {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "ContactSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Giriş yapmanız gerekiyor"])
        }

        let token = try await user.getIDToken()

        guard let url = URL(string: callableURL) else {
            throw NSError(domain: "ContactSync", code: 0, userInfo: [NSLocalizedDescriptionKey: "Geçersiz URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["data": ["phoneHashes": phoneHashes]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "ContactSync", code: 500, userInfo: [NSLocalizedDescriptionKey: "Sunucu hatası"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let matches = result["matches"] as? [[String: Any]] else {
            throw NSError(domain: "ContactSync", code: 0, userInfo: [NSLocalizedDescriptionKey: "Sunucu yanıtı geçersiz"])
        }

        return matches
    }

    // MARK: - Helpers

    static func normalizePhone(_ phone: String) -> String {
        var digits = phone.filter { $0.isNumber }
        // Add Turkey country code if needed
        if digits.count == 11 && digits.hasPrefix("0") {
            digits = "90" + String(digits.dropFirst())
        } else if digits.count == 10 {
            digits = "90" + digits
        }
        return digits
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
