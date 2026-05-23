import Foundation
import FirebaseStorage

/// Storage operations StripMate's services actually use. No FirebaseStorage
/// types cross the boundary — only `Data`, `String` paths, `URL`, and
/// optional metadata. Mockable in tests.
public protocol StorageClient: Sendable {
    /// Upload data to a path. Returns the public download URL string on success.
    func uploadData(_ data: Data, to path: String, contentType: String?) async throws -> String

    /// Delete the object at the given path. No-op if it doesn't exist.
    func deleteObject(at path: String) async throws

    /// Returns the download URL for an existing object.
    func downloadURL(for path: String) async throws -> String
}

// MARK: - Production Firebase impl

public final class FirebaseStorageClient: StorageClient, @unchecked Sendable {
    public static let shared = FirebaseStorageClient()
    private var ref: StorageReference { Storage.storage().reference() }

    public init() {}

    public func uploadData(_ data: Data, to path: String, contentType: String?) async throws -> String {
        let metadata = StorageMetadata()
        if let ct = contentType { metadata.contentType = ct }
        let target = ref.child(path)
        _ = try await target.putDataAsync(data, metadata: metadata)
        let url = try await target.downloadURL()
        return url.absoluteString
    }

    public func deleteObject(at path: String) async throws {
        try await ref.child(path).delete()
    }

    public func downloadURL(for path: String) async throws -> String {
        let url = try await ref.child(path).downloadURL()
        return url.absoluteString
    }
}
