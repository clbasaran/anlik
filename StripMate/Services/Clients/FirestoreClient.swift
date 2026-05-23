import Foundation
import FirebaseFirestore

/// A thin protocol that abstracts the Firestore operations StripMate's services
/// actually use. Crossing this boundary, callers and implementations only deal
/// with `[String: Any]` dictionaries and primitive types — no Firestore SDK
/// types leak through, which makes the services trivially mockable in tests.
///
/// Production wiring uses `FirebaseFirestoreClient` (this file).
/// Tests can use `MockFirestoreClient` (in StripMateTests/) instead.
public protocol FirestoreClient: Sendable {
    /// Returns the document data for the given path, or nil if the document doesn't exist.
    func getDocument(path: String) async throws -> [String: Any]?

    /// Writes the given data to the document path. If `merge` is true, fields are
    /// merged with existing fields; otherwise the document is overwritten.
    func setDocument(path: String, data: [String: Any], merge: Bool) async throws

    /// Updates specific fields of an existing document. Throws if document doesn't exist.
    func updateDocument(path: String, data: [String: Any]) async throws

    /// Deletes the document at the given path. No-op if it doesn't exist.
    func deleteDocument(path: String) async throws

    /// Runs a query against a collection with optional filters, ordering, and limit.
    /// Returns an array of (documentID, data) tuples. Each entry's `data` includes
    /// only the document fields — the ID is returned separately.
    func queryDocuments(
        collection: String,
        filters: [QueryFilter],
        orderBy: QueryOrder?,
        limit: Int?
    ) async throws -> [QueryResult]

    /// Lists all documents in a subcollection of a parent path.
    func listSubcollection(parentPath: String, name: String) async throws -> [QueryResult]
}

/// A query filter expressed in client-neutral terms. The Firestore client
/// translates these into the appropriate Firestore Query API calls.
public enum QueryFilter: Sendable {
    case isEqualTo(field: String, value: any Sendable)
    case isNotEqualTo(field: String, value: any Sendable)
    case arrayContains(field: String, value: any Sendable)
    case isIn(field: String, values: [any Sendable])
}

public struct QueryOrder: Sendable {
    public let field: String
    public let descending: Bool
    public init(field: String, descending: Bool = false) {
        self.field = field
        self.descending = descending
    }
}

public struct QueryResult: Sendable {
    public let id: String
    public let data: [String: Any]
    public init(id: String, data: [String: Any]) {
        self.id = id
        self.data = data
    }
}

// MARK: - Production Firestore implementation

public final class FirebaseFirestoreClient: FirestoreClient, @unchecked Sendable {
    public static let shared = FirebaseFirestoreClient()
    private var db: Firestore { Firestore.firestore() }

    public init() {}

    public func getDocument(path: String) async throws -> [String: Any]? {
        let snapshot = try await db.document(path).getDocument()
        return snapshot.data()
    }

    public func setDocument(path: String, data: [String: Any], merge: Bool) async throws {
        try await db.document(path).setData(data, merge: merge)
    }

    public func updateDocument(path: String, data: [String: Any]) async throws {
        try await db.document(path).updateData(data)
    }

    public func deleteDocument(path: String) async throws {
        try await db.document(path).delete()
    }

    public func queryDocuments(
        collection: String,
        filters: [QueryFilter],
        orderBy: QueryOrder?,
        limit: Int?
    ) async throws -> [QueryResult] {
        var query: Query = db.collection(collection)
        for filter in filters {
            switch filter {
            case .isEqualTo(let field, let value):
                query = query.whereField(field, isEqualTo: value)
            case .isNotEqualTo(let field, let value):
                query = query.whereField(field, isNotEqualTo: value)
            case .arrayContains(let field, let value):
                query = query.whereField(field, arrayContains: value)
            case .isIn(let field, let values):
                query = query.whereField(field, in: values)
            }
        }
        if let order = orderBy {
            query = query.order(by: order.field, descending: order.descending)
        }
        if let limit = limit {
            query = query.limit(to: limit)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.map { QueryResult(id: $0.documentID, data: $0.data()) }
    }

    public func listSubcollection(parentPath: String, name: String) async throws -> [QueryResult] {
        let snapshot = try await db.document(parentPath).collection(name).getDocuments()
        return snapshot.documents.map { QueryResult(id: $0.documentID, data: $0.data()) }
    }
}
