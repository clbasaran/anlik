import Foundation
import StoreKit

/// StoreKit 2 scaffold for the app's cosmetic-only monetization model.
///
/// Model constraints (product decisions, not code):
/// - Core loop is NEVER paywalled: friends, uploads, chat, widgets stay free.
/// - No ads, ever.
/// - Products are cosmetic/ritual only (frame packs, app icon packs, tip jar).
///
/// The catalog below is a PROPOSAL — the product IDs are not yet created in
/// App Store Connect. Creating them (and choosing prices) is a user decision;
/// until then `Store.products` simply loads empty and no UI references this
/// service. Once products exist in ASC, the same IDs here start resolving with
/// zero code changes.
@MainActor
@Observable
public final class StoreService {
    public static let shared = StoreService()

    /// Proposed cosmetic catalog. IDs follow the app's bundle-id convention.
    public enum Catalog: String, CaseIterable {
        /// One-time "destek ol" tips (consumable) — pure gratitude, no perks.
        case tipSmall = "com.celalbasaran.stripmate.tip.small"
        case tipLarge = "com.celalbasaran.stripmate.tip.large"
        /// Cosmetic photo frame pack for sent moments (non-consumable).
        case framesRetro = "com.celalbasaran.stripmate.frames.retro"
        /// Alternate app icon pack (non-consumable).
        case iconsMono = "com.celalbasaran.stripmate.icons.mono"
    }

    /// Products that resolved from the App Store; empty until the catalog
    /// exists in ASC.
    public private(set) var products: [Product] = []

    /// Product IDs the user owns (non-consumables only; tips don't persist).
    public private(set) var ownedProductIDs: Set<String> = []

    public private(set) var isLoading = false

    private var transactionListener: Task<Void, Never>?

    private init() {}

    /// Starts the transaction update listener and loads products + current
    /// entitlements. Safe to call multiple times.
    public func start() {
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update: update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Catalog.allCases.map(\.rawValue))
        } catch {
            AppLogger.service.error("Store: products failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Purchases a product and updates entitlements on success.
    /// Returns true when the purchase completed (not pending/cancelled).
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            AppLogger.service.error("Store: purchase failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Rebuilds the owned set from current entitlements (App Store is the
    /// source of truth — survives reinstall and family sharing).
    public func refreshEntitlements() async {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
    }

    public func owns(_ item: Catalog) -> Bool {
        ownedProductIDs.contains(item.rawValue)
    }

    private func handle(update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
