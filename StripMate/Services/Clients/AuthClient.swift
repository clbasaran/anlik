import Foundation
import FirebaseAuth

/// Authentication operations StripMate's services actually use.
/// No FirebaseAuth types cross the boundary — only `String` UIDs and emails —
/// so services are mockable without Firebase.
public protocol AuthClient: Sendable {
    /// The currently signed-in user's uid, or nil if signed out.
    var currentUserId: String? { get }

    /// The currently signed-in user's email, if any.
    var currentUserEmail: String? { get }

    /// Sign in with email/password. Returns the new user's uid on success.
    func signIn(email: String, password: String) async throws -> String

    /// Create a new user with email/password. Returns the new user's uid.
    func createUser(email: String, password: String) async throws -> String

    /// Sign in with Apple via OIDC token + nonce. Returns the user's uid.
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> String

    /// Sign out the current user.
    func signOut() throws

    /// Send a password reset email.
    func sendPasswordReset(email: String) async throws

    /// Delete the current user account.
    func deleteCurrentUser() async throws
}

// MARK: - Production Firebase impl

public final class FirebaseAuthClient: AuthClient, @unchecked Sendable {
    public static let shared = FirebaseAuthClient()

    public init() {}

    public var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    public var currentUserEmail: String? {
        Auth.auth().currentUser?.email
    }

    public func signIn(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user.uid
    }

    public func createUser(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
    }

    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> String {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil  // Pass nil — Firebase computes display name from token if available
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user.uid
    }

    public func signOut() throws {
        try Auth.auth().signOut()
    }

    public func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    public func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseError.unauthenticated
        }
        try await user.delete()
    }
}
