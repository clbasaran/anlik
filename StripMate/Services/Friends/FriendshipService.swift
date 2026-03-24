import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles friend requests, accepting, removing, and fetching friends.
public actor FriendshipService {
    public static let shared = FriendshipService()
    
    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }
    
    private init() {}
    
    public func sendFriendRequest(to targetUserId: String) async throws {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        guard currentId != targetUserId else { throw FirebaseError.pairingFailed }
        
        // Friend limit: max 50 active friends
        let existingFriends = try await db.collection("users").document(currentId)
            .collection("friendships")
            .whereField("isPending", isEqualTo: false)
            .count.getAggregation(source: .server)
        let friendCount = existingFriends.count.intValue
        guard friendCount < 50 else {
            throw AppError.custom(String(localized: "maksimum 50 arkadaş limitine ulaştın."))
        }
        
        let batch = db.batch()
        
        let outboundRef = db.collection("users").document(currentId).collection("friendships").document(targetUserId)
        batch.setData([
            "userId": targetUserId,
            "isPending": true,
            "requesterId": currentId,
            "timestamp": FieldValue.serverTimestamp()
        ], forDocument: outboundRef)
        
        let inboundRef = db.collection("users").document(targetUserId).collection("friendships").document(currentId)
        batch.setData([
            "userId": currentId,
            "isPending": true,
            "requesterId": currentId,
            "timestamp": FieldValue.serverTimestamp()
        ], forDocument: inboundRef)
        
        try await batch.commit()
    }
    
    public func acceptFriendRequest(from requesterId: String) async throws {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        let batch = db.batch()
        
        let outboundRef = db.collection("users").document(currentId).collection("friendships").document(requesterId)
        batch.updateData(["isPending": false], forDocument: outboundRef)
        
        let inboundRef = db.collection("users").document(requesterId).collection("friendships").document(currentId)
        batch.updateData(["isPending": false], forDocument: inboundRef)
        
        try await batch.commit()
    }
    
    public func fetchFriends() async throws -> [FriendStatus] {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        let snapshot = try await db.collection("users").document(currentId).collection("friendships").getDocuments()
        
        var friendEntries: [(userId: String, isPending: Bool, timestamp: Date, requesterId: String?)] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let isPending = data["isPending"] as? Bool else { continue }
            let stamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let requesterId = data["requesterId"] as? String
            friendEntries.append((userId: userId, isPending: isPending, timestamp: stamp, requesterId: requesterId))
        }
        
        // Batch fetch profiles (Firestore supports up to 30 IDs per `in` query)
        let allIds = friendEntries.map { $0.userId }
        var profileMap: [String: UserProfile] = [:]
        
        let chunks = stride(from: 0, to: allIds.count, by: 30).map {
            Array(allIds[$0..<min($0 + 30, allIds.count)])
        }
        
        for chunk in chunks {
            guard !chunk.isEmpty else { continue }
            let profileSnapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            for doc in profileSnapshot.documents {
                let data = doc.data()
                let dob = (data["dateOfBirth"] as? Timestamp)?.dateValue()
                let profile = UserProfile(
                    id: doc.documentID,
                    inviteCode: data["inviteCode"] as? String ?? "",
                    email: data["email"] as? String,
                    displayName: data["displayName"] as? String,
                    username: data["username"] as? String,
                    dateOfBirth: dob,
                    avatarUrl: data["avatarUrl"] as? String,
                    bio: data["bio"] as? String
                )
                profileMap[doc.documentID] = profile
            }
        }
        
        let friends = friendEntries.map { entry in
            FriendStatus(
                userId: entry.userId,
                isPending: entry.isPending,
                timestamp: entry.timestamp,
                requesterId: entry.requesterId,
                profile: profileMap[entry.userId]
            )
        }
        
        await SwiftDataSyncService.shared.syncFriendsToLocal(friends)
        
        return friends
    }
    
    public func removeFriend(_ friendId: String) async throws {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        let batch = db.batch()
        let outboundRef = db.collection("users").document(currentId).collection("friendships").document(friendId)
        let inboundRef = db.collection("users").document(friendId).collection("friendships").document(currentId)
        
        batch.deleteDocument(outboundRef)
        batch.deleteDocument(inboundRef)
        
        try await batch.commit()
    }
    
    /// En az 1 kabul edilmiş arkadaşı var mı kontrol et (Friend Gate için)
    public func hasAcceptedFriends() async -> Bool {
        guard let currentId = auth.currentUser?.uid else { return false }
        do {
            let snapshot = try await db.collection("users").document(currentId)
                .collection("friendships")
                .whereField("isPending", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    /// Herhangi bir arkadaşlık kaydı var mı (pending dahil) — Friend Gate geçişi için
    public func hasAnyFriendship() async -> Bool {
        guard let currentId = auth.currentUser?.uid else { return false }
        do {
            let snapshot = try await db.collection("users").document(currentId)
                .collection("friendships")
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    /// Gelen bekleyen arkadaşlık isteklerini getir (profil bilgileriyle)
    public func fetchPendingIncomingRequests() async throws -> [FriendStatus] {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        // Cache'ten eski veri gelmemesi için sunucudan çek
        let snapshot = try await db.collection("users").document(currentId)
            .collection("friendships")
            .whereField("isPending", isEqualTo: true)
            .getDocuments(source: .server)

        // Sadece gelen istekler: requesterId farklı olan VE doc ID (friendId) requesterId olan
        let incoming = snapshot.documents.filter { doc in
            let data = doc.data()
            let requesterId = data["requesterId"] as? String
            // requesterId == currentId ise BEN gönderdim, filtrele
            return requesterId != nil && requesterId != currentId
        }

        guard !incoming.isEmpty else { return [] }

        // Profil bilgilerini çek
        let userIds = incoming.compactMap { $0.data()["userId"] as? String }
        var profileMap: [String: UserProfile] = [:]
        for chunk in stride(from: 0, to: userIds.count, by: 30).map({ Array(userIds[$0..<min($0 + 30, userIds.count)]) }) {
            let profileSnap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for doc in profileSnap.documents {
                let data = doc.data()
                profileMap[doc.documentID] = UserProfile(
                    id: doc.documentID,
                    inviteCode: data["inviteCode"] as? String ?? "",
                    email: data["email"] as? String,
                    displayName: data["displayName"] as? String,
                    username: data["username"] as? String,
                    dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
                    avatarUrl: data["avatarUrl"] as? String,
                    bio: data["bio"] as? String
                )
            }
        }

        return incoming.map { doc in
            let data = doc.data()
            return FriendStatus(
                userId: data["userId"] as? String ?? doc.documentID,
                isPending: true,
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                requesterId: data["requesterId"] as? String,
                profile: profileMap[data["userId"] as? String ?? doc.documentID]
            )
        }
    }

    public func fetchPendingRequestsCount() async -> Int {
        guard let currentId = auth.currentUser?.uid else { return 0 }
        do {
            let snapshot = try await db.collection("users").document(currentId).collection("friendships")
                .whereField("isPending", isEqualTo: true)
                .getDocuments()
            
            let incoming = snapshot.documents.filter { doc in
                let data = doc.data()
                let requesterId = data["requesterId"] as? String
                return requesterId != currentId
            }
            return incoming.count
        } catch {
            return 0
        }
    }
}
