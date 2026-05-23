import Foundation
@testable import StripMate

/// In-memory FirestoreClient implementation for tests. Models documents as a
/// path → dictionary map. Supports basic queries (filters + ordering + limit).
public final class MockFirestoreClient: FirestoreClient, @unchecked Sendable {
    /// path → data
    public var documents: [String: [String: Any]] = [:]

    /// Inject errors to test failure paths. Set the relevant property to a
    /// non-nil error and the next matching call will throw it.
    public var nextGetError: Error?
    public var nextSetError: Error?
    public var nextUpdateError: Error?
    public var nextDeleteError: Error?
    public var nextQueryError: Error?

    /// Call counters
    public var getDocumentCalls = 0
    public var setDocumentCalls = 0
    public var updateDocumentCalls = 0
    public var deleteDocumentCalls = 0
    public var queryDocumentsCalls = 0
    public var listSubcollectionCalls = 0

    public init() {}

    public func getDocument(path: String) async throws -> [String: Any]? {
        getDocumentCalls += 1
        if let err = nextGetError { nextGetError = nil; throw err }
        return documents[path]
    }

    public func setDocument(path: String, data: [String: Any], merge: Bool) async throws {
        setDocumentCalls += 1
        if let err = nextSetError { nextSetError = nil; throw err }
        if merge, var existing = documents[path] {
            for (k, v) in data { existing[k] = v }
            documents[path] = existing
        } else {
            documents[path] = data
        }
    }

    public func updateDocument(path: String, data: [String: Any]) async throws {
        updateDocumentCalls += 1
        if let err = nextUpdateError { nextUpdateError = nil; throw err }
        guard var existing = documents[path] else {
            throw NSError(domain: "MockFirestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found at \(path)"])
        }
        for (k, v) in data { existing[k] = v }
        documents[path] = existing
    }

    public func deleteDocument(path: String) async throws {
        deleteDocumentCalls += 1
        if let err = nextDeleteError { nextDeleteError = nil; throw err }
        documents.removeValue(forKey: path)
    }

    public func queryDocuments(
        collection: String,
        filters: [QueryFilter],
        orderBy: QueryOrder?,
        limit: Int?
    ) async throws -> [QueryResult] {
        queryDocumentsCalls += 1
        if let err = nextQueryError { nextQueryError = nil; throw err }

        // Find all docs whose path is "collection/X"
        let prefix = "\(collection)/"
        var results: [QueryResult] = documents
            .filter { $0.key.hasPrefix(prefix) && !$0.key.dropFirst(prefix.count).contains("/") }
            .map { (path, data) in
                let id = String(path.dropFirst(prefix.count))
                return QueryResult(id: id, data: data)
            }

        // Apply filters
        for filter in filters {
            switch filter {
            case .isEqualTo(let field, let value):
                results = results.filter { Self.equalAny($0.data[field], value) }
            case .isNotEqualTo(let field, let value):
                results = results.filter { !Self.equalAny($0.data[field], value) }
            case .arrayContains(let field, let value):
                results = results.filter { ($0.data[field] as? [Any])?.contains(where: { Self.equalAny($0, value) }) == true }
            case .isIn(let field, let values):
                if field == "__name__" {
                    let strings = values.compactMap { $0 as? String }
                    results = results.filter { strings.contains($0.id) }
                } else {
                    results = results.filter { value in
                        values.contains(where: { Self.equalAny(value.data[field], $0) })
                    }
                }
            }
        }

        // Order by
        if let order = orderBy {
            results.sort { a, b in
                let av = a.data[order.field]
                let bv = b.data[order.field]
                if let ai = av as? Int, let bi = bv as? Int { return order.descending ? ai > bi : ai < bi }
                if let ad = av as? Date, let bd = bv as? Date { return order.descending ? ad > bd : ad < bd }
                if let ad = av as? Double, let bd = bv as? Double { return order.descending ? ad > bd : ad < bd }
                if let ai = av as? String, let bi = bv as? String { return order.descending ? ai > bi : ai < bi }
                return false
            }
        }

        if let limit = limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    public func listSubcollection(parentPath: String, name: String) async throws -> [QueryResult] {
        listSubcollectionCalls += 1
        let prefix = "\(parentPath)/\(name)/"
        return documents
            .filter { $0.key.hasPrefix(prefix) && !$0.key.dropFirst(prefix.count).contains("/") }
            .map { (path, data) in
                let id = String(path.dropFirst(prefix.count))
                return QueryResult(id: id, data: data)
            }
    }

    /// Compare two `Any` values for equality in the limited cases this mock
    /// needs to support. Extend as test cases require.
    private static func equalAny(_ a: Any?, _ b: Any) -> Bool {
        if let aS = a as? String, let bS = b as? String { return aS == bS }
        if let aI = a as? Int, let bI = b as? Int { return aI == bI }
        if let aD = a as? Double, let bD = b as? Double { return aD == bD }
        if let aB = a as? Bool, let bB = b as? Bool { return aB == bB }
        return false
    }
}

// MARK: - Mock AuthClient

public final class MockAuthClient: AuthClient, @unchecked Sendable {
    public var currentUserId: String?
    public var currentUserEmail: String?

    public var nextSignInError: Error?
    public var nextCreateUserError: Error?
    public var nextSignInWithAppleError: Error?
    public var nextSignOutError: Error?
    public var nextSendPasswordResetError: Error?
    public var nextDeleteCurrentUserError: Error?

    public var signInCalled = false
    public var createUserCalled = false
    public var signInWithAppleCalled = false
    public var signOutCalled = false
    public var sendPasswordResetCalled = false
    public var deleteCurrentUserCalled = false

    public var lastSignInEmail: String?
    public var lastSignInPassword: String?
    public var lastResetEmail: String?

    public init(initialUid: String? = nil, initialEmail: String? = nil) {
        self.currentUserId = initialUid
        self.currentUserEmail = initialEmail
    }

    public func signIn(email: String, password: String) async throws -> String {
        signInCalled = true
        lastSignInEmail = email
        lastSignInPassword = password
        if let err = nextSignInError { nextSignInError = nil; throw err }
        let uid = "mock_uid_\(email.prefix(5))"
        currentUserId = uid
        currentUserEmail = email
        return uid
    }

    public func createUser(email: String, password: String) async throws -> String {
        createUserCalled = true
        if let err = nextCreateUserError { nextCreateUserError = nil; throw err }
        let uid = "mock_uid_new_\(email.prefix(5))"
        currentUserId = uid
        currentUserEmail = email
        return uid
    }

    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> String {
        signInWithAppleCalled = true
        if let err = nextSignInWithAppleError { nextSignInWithAppleError = nil; throw err }
        let uid = "mock_apple_uid"
        currentUserId = uid
        return uid
    }

    public func signOut() throws {
        signOutCalled = true
        if let err = nextSignOutError { nextSignOutError = nil; throw err }
        currentUserId = nil
        currentUserEmail = nil
    }

    public func sendPasswordReset(email: String) async throws {
        sendPasswordResetCalled = true
        lastResetEmail = email
        if let err = nextSendPasswordResetError { nextSendPasswordResetError = nil; throw err }
    }

    public func deleteCurrentUser() async throws {
        deleteCurrentUserCalled = true
        if let err = nextDeleteCurrentUserError { nextDeleteCurrentUserError = nil; throw err }
        currentUserId = nil
        currentUserEmail = nil
    }
}
