import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles friend requests, accepting, removing, and fetching friends.
public actor FriendshipService {
    public static let shared = FriendshipService()

    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }

    /// Tracks in-flight mutating operations by target user ID to prevent duplicates.
    private var inFlightOperations: Set<String> = []

    private init() {}

    /// Returns true if the operation was successfully claimed (not already in-flight).
    private func claimOperation(_ key: String) -> Bool {
        guard !inFlightOperations.contains(key) else { return false }
        inFlightOperations.insert(key)
        return true
    }

    private func releaseOperation(_ key: String) {
        inFlightOperations.remove(key)
    }
    
    public func sendFriendRequest(to targetUserId: String) async throws {
        CrashReporter.shared.breadcrumb(.app, "sendFriendRequest")
        defer {
            // Outgoing requests don't immediately add a friend to the receiver
            // list, but the inbox view still needs to refresh — broadcast so
            // any listening cache invalidates.
            NotificationCenter.default.post(name: .friendListChanged, object: nil)
        }
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        guard currentId != targetUserId else { throw FirebaseError.pairingFailed }

        let operationKey = "send_\(targetUserId)"
        guard claimOperation(operationKey) else { return }
        defer { releaseOperation(operationKey) }

        // Friend limit: max 50 active friends
        let existingFriends = try await db.collection("users").document(currentId)
            .collection("friendships")
            .whereField("isPending", isEqualTo: false)
            .count.getAggregation(source: .server)
        let friendCount = existingFriends.count.intValue
        guard friendCount < 50 else {
            throw AppError.custom(String(localized: "maksimum 50 arkadaş limitine ulaştın."))
        }

        // Use a transaction to atomically check-then-write
        let outboundRef = db.collection("users").document(currentId)
            .collection("friendships").document(targetUserId)
        let inboundRef = db.collection("users").document(targetUserId)
            .collection("friendships").document(currentId)

        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Read inside transaction to prevent TOCTOU race
            let existingDoc: DocumentSnapshot
            do {
                existingDoc = try transaction.getDocument(outboundRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            if existingDoc.exists, let existingData = existingDoc.data() {
                let isPending = existingData["isPending"] as? Bool ?? true
                if !isPending {
                    let err = NSError(
                        domain: "FriendshipService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Bu kişi zaten arkadaş listenizde.")]
                    )
                    errorPointer?.pointee = err
                } else {
                    let err = NSError(
                        domain: "FriendshipService",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Bu kişiye zaten bir arkadaşlık isteği gönderilmiş.")]
                    )
                    errorPointer?.pointee = err
                }
                return nil
            }

            transaction.setData([
                "userId": targetUserId,
                "isPending": true,
                "requesterId": currentId,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: outboundRef)

            transaction.setData([
                "userId": currentId,
                "isPending": true,
                "requesterId": currentId,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: inboundRef)

            return nil
        })
    }
    
    public func acceptFriendRequest(from requesterId: String) async throws {
        CrashReporter.shared.breadcrumb(.app, "acceptFriendRequest")
        defer {
            // Triggers Camera/Preview/Inbox to drop their cached friend lists
            // so the new friend appears in the send sheet without an app
            // restart.
            NotificationCenter.default.post(name: .friendListChanged, object: nil)
        }
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        let operationKey = "accept_\(requesterId)"
        guard claimOperation(operationKey) else { return }
        defer { releaseOperation(operationKey) }

        let outboundRef = db.collection("users").document(currentId)
            .collection("friendships").document(requesterId)
        let inboundRef = db.collection("users").document(requesterId)
            .collection("friendships").document(currentId)

        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Verify the request still exists and is actually pending
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(outboundRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard doc.exists,
                  let data = doc.data(),
                  let isPending = data["isPending"] as? Bool,
                  isPending else {
                // Already accepted or deleted -- nothing to do
                return nil
            }

            transaction.updateData(["isPending": false], forDocument: outboundRef)
            transaction.updateData(["isPending": false], forDocument: inboundRef)
            return nil
        })
    }
    
    public func fetchFriends() async throws -> [FriendStatus] {
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        let snapshot = try await db.collection("users").document(currentId).collection("friendships").getDocuments()
        
        var friendEntries: [(userId: String, isPending: Bool, timestamp: Date, requesterId: String?, isFavorite: Bool)] = []

        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let isPending = data["isPending"] as? Bool else { continue }
            let stamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let requesterId = data["requesterId"] as? String
            let isFavorite = data["isFavorite"] as? Bool ?? false
            friendEntries.append((userId: userId, isPending: isPending, timestamp: stamp, requesterId: requesterId, isFavorite: isFavorite))
        }
        
        // Batch fetch profiles in parallel (Firestore supports up to 30 IDs per `in` query).
        // Running chunks in parallel cuts N+1 latency from O(chunks) to O(1) round trips.
        let allIds = friendEntries.map { $0.userId }
        let chunks = stride(from: 0, to: allIds.count, by: 30).map {
            Array(allIds[$0..<min($0 + 30, allIds.count)])
        }

        let db = self.db
        var profileMap: [String: UserProfile] = [:]
        try await withThrowingTaskGroup(of: [UserProfile].self) { group in
            for chunk in chunks where !chunk.isEmpty {
                group.addTask {
                    let profileSnapshot = try await db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    return profileSnapshot.documents.map { doc in
                        let data = doc.data()
                        let dob = (data["dateOfBirth"] as? Timestamp)?.dateValue()
                        return UserProfile(
                            id: doc.documentID,
                            inviteCode: data["inviteCode"] as? String ?? "",
                            email: data["email"] as? String,
                            displayName: data["displayName"] as? String,
                            username: data["username"] as? String,
                            dateOfBirth: dob,
                            avatarUrl: data["avatarUrl"] as? String,
                            bio: data["bio"] as? String
                        )
                    }
                }
            }
            for try await profiles in group {
                for profile in profiles {
                    profileMap[profile.id] = profile
                }
            }
        }
        
        let friends = friendEntries.map { entry in
            FriendStatus(
                userId: entry.userId,
                isPending: entry.isPending,
                timestamp: entry.timestamp,
                requesterId: entry.requesterId,
                profile: profileMap[entry.userId],
                isFavorite: entry.isFavorite
            )
        }
        
        await SwiftDataSyncService.shared.syncFriendsToLocal(friends)
        
        return friends
    }
    
    public func removeFriend(_ friendId: String) async throws {
        CrashReporter.shared.breadcrumb(.app, "removeFriend")
        defer {
            NotificationCenter.default.post(name: .friendListChanged, object: nil)
        }
        guard let currentId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        let operationKey = "remove_\(friendId)"
        guard claimOperation(operationKey) else { return }
        defer { releaseOperation(operationKey) }

        let batch = db.batch()
        let outboundRef = db.collection("users").document(currentId)
            .collection("friendships").document(friendId)
        let inboundRef = db.collection("users").document(friendId)
            .collection("friendships").document(currentId)

        batch.deleteDocument(outboundRef)
        batch.deleteDocument(inboundRef)

        try await batch.commit()
    }
    
    /// Toggle the sender-side favorite flag for a friend. Stored at
    /// users/{currentUid}/friendships/{friendUid}.isFavorite. Other-side write
    /// is intentional no-op — favorites are per-viewer, like an address book star.
    public func setFavorite(friendId: String, isFavorite: Bool) async throws {
        guard let currentId = auth.currentUser?.uid else { throw AppError.unauthenticated }
        try await db.collection("users").document(currentId)
            .collection("friendships").document(friendId)
            .setData(["isFavorite": isFavorite], merge: true)
        NotificationCenter.default.post(name: .friendListChanged, object: nil)
    }

    /// Kabul edilmiş arkadaş sayısını döner. <3 ise öneri akışını tetiklemek için kullanılır.
    public func acceptedFriendCount() async -> Int {
        guard let currentId = auth.currentUser?.uid else { return 0 }
        do {
            let snapshot = try await db.collection("users").document(currentId)
                .collection("friendships")
                .whereField("isPending", isEqualTo: false)
                .count.getAggregation(source: .server)
            return Int(truncating: snapshot.count)
        } catch {
            return 0
        }
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

    /// Gelen bekleyen istekleri canlı dinle (Friend Gate için)
    public func listenToPendingIncomingRequests() -> AsyncThrowingStream<[FriendStatus], Error> {
        AsyncThrowingStream { continuation in
            guard let currentId = auth.currentUser?.uid else {
                continuation.finish(throwing: FirebaseError.unauthenticated)
                return
            }

            let query = db.collection("users").document(currentId)
                .collection("friendships")
                .whereField("isPending", isEqualTo: true)

            let listener = query.addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let snapshot, let self else {
                    continuation.yield([])
                    return
                }

                Task {
                    do {
                        let requests = try await self.mapIncomingPendingRequests(
                            snapshot.documents,
                            currentId: currentId
                        )
                        continuation.yield(requests)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private func mapIncomingPendingRequests(
        _ documents: [QueryDocumentSnapshot],
        currentId: String
    ) async throws -> [FriendStatus] {
        let incoming = documents.filter { doc in
            let data = doc.data()
            let requesterId = data["requesterId"] as? String
            return requesterId != nil && requesterId != currentId
        }

        guard !incoming.isEmpty else { return [] }

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
            let userId = data["userId"] as? String ?? doc.documentID
            return FriendStatus(
                userId: userId,
                isPending: true,
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                requesterId: data["requesterId"] as? String,
                profile: profileMap[userId]
            )
        }
    }
}
