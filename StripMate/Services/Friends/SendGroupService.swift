import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Manages user-defined recipient groups stored at
/// users/{uid}/send_groups/{groupId}. Used by the send sheet to give power-users
/// one-tap selection of common recipient sets ("aile", "arkadaşlar", etc.).
public actor SendGroupService {
    public static let shared = SendGroupService()

    private let db = Firestore.firestore()
    private var auth: FirebaseAuth.Auth { Auth.auth() }

    /// Notification posted whenever a group is created/updated/deleted so
    /// observers (FriendSelectionSheet, GroupsListView) can refetch.
    public static let groupsChangedNotification = Notification.Name("SendGroupService.groupsChanged")

    private init() {}

    public func fetchGroups() async throws -> [SendGroup] {
        guard let uid = auth.currentUser?.uid else { throw AppError.unauthenticated }
        let snap = try await db.collection("users").document(uid)
            .collection("send_groups")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snap.documents.compactMap { Self.parse(doc: $0) }
    }

    public func createGroup(name: String, memberIds: [String]) async throws -> SendGroup {
        guard let uid = auth.currentUser?.uid else { throw AppError.unauthenticated }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else {
            throw NSError(domain: "SendGroup", code: 1, userInfo: [NSLocalizedDescriptionKey: "İsim 1-40 karakter olmalı"])
        }
        guard !memberIds.isEmpty else {
            throw NSError(domain: "SendGroup", code: 2, userInfo: [NSLocalizedDescriptionKey: "En az bir kişi seç"])
        }
        let group = SendGroup(name: trimmed, memberIds: memberIds)
        try await db.collection("users").document(uid)
            .collection("send_groups").document(group.id)
            .setData([
                "name": group.name,
                "memberIds": group.memberIds,
                "createdAt": Timestamp(date: group.createdAt)
            ])
        await MainActor.run {
            NotificationCenter.default.post(name: Self.groupsChangedNotification, object: nil)
        }
        return group
    }

    public func updateGroup(id: String, name: String, memberIds: [String]) async throws {
        guard let uid = auth.currentUser?.uid else { throw AppError.unauthenticated }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else {
            throw NSError(domain: "SendGroup", code: 1, userInfo: [NSLocalizedDescriptionKey: "İsim 1-40 karakter olmalı"])
        }
        try await db.collection("users").document(uid)
            .collection("send_groups").document(id)
            .updateData([
                "name": trimmed,
                "memberIds": memberIds
            ])
        await MainActor.run {
            NotificationCenter.default.post(name: Self.groupsChangedNotification, object: nil)
        }
    }

    public func deleteGroup(id: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw AppError.unauthenticated }
        try await db.collection("users").document(uid)
            .collection("send_groups").document(id).delete()
        await MainActor.run {
            NotificationCenter.default.post(name: Self.groupsChangedNotification, object: nil)
        }
    }

    nonisolated private static func parse(doc: QueryDocumentSnapshot) -> SendGroup? {
        let data = doc.data()
        guard let name = data["name"] as? String,
              let memberIds = data["memberIds"] as? [String] else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return SendGroup(id: doc.documentID, name: name, memberIds: memberIds, createdAt: createdAt)
    }
}
