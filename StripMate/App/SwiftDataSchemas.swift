import Foundation
import SwiftData

// MARK: - SwiftData Schema Versioning

/// Schema versions are kept side-by-side so the migration plan can declare the
/// path between them. When you add or remove a field on a `@Model` type, copy
/// the most recent enum (e.g. StripMateSchemaV2) into a new StripMateSchemaV3,
/// flip the `models` types in `sharedModelContainer` to the new shape, and
/// append a `MigrationStage` from the previous version to the new one.
///
/// Without a defined path, an in-flight on-disk store risks being wiped on
/// upgrade (see fallback in `sharedModelContainer`). With it, lightweight
/// migrations stay automatic and additive changes are seamless.
enum StripMateSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

/// V2 is shape-identical to V1 today — the bump exists to install the
/// migration pipeline so the next field change has a place to live. Future:
/// when Comment / DirectMessage / Achievement / Streak become @Model classes
/// (currently Codable structs cached only in memory), bump to V3 and add the
/// new model types here plus a custom MigrationStage if any data needs
/// transforming.
enum StripMateSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

/// V3 adds `Friend.isFavorite: Bool` (default false). Lightweight migration —
/// SwiftData backfills the new column with the default value for every
/// existing row. Without this stage, V2 stores crash on launch with
/// `NSLightweightMigrationStage initWithVersionChecksums` (the classic
/// "schema changed without a stage to bridge it" failure).
enum StripMateSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

enum StripMateMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StripMateSchemaV1.self, StripMateSchemaV2.self, StripMateSchemaV3.self]
    }

    /// V1 → V2 is a no-op shape-wise; declaring it as `lightweight` lets
    /// SwiftData's inference handle the version metadata bump without a
    /// destructive rebuild of an existing user's local cache.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: StripMateSchemaV1.self,
        toVersion: StripMateSchemaV2.self
    )

    /// V2 → V3 adds Friend.isFavorite — pure additive, lightweight is enough.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: StripMateSchemaV2.self,
        toVersion: StripMateSchemaV3.self
    )

    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }
}

// MARK: - Schema Fingerprint & On-Disk Store Reset

/// Bumped on every additive schema change — when this string differs from the
/// last value stored in UserDefaults at launch, we nuke the on-disk SwiftData
/// store before opening it. The store is just a cache of Firestore, so losing
/// it is safe; the next listener tick refills it.
///
/// This sidesteps SwiftData's `NSLightweightMigrationStage initWithVersionChecksums`
/// crash, which fires when the in-code schema and on-disk schema disagree
/// AND the migration plan can't compute checksums (since both versioned
/// schemas in the plan now reference the live model type, not a snapshot).
private let kSwiftDataSchemaFingerprint = "v3-friend-isFavorite-2026-04-27"
private let kSwiftDataFingerprintKey = "stripmate.swiftdata.schemaFingerprint"

private func nukeSwiftDataStoreIfSchemaChanged(at storeURL: URL?) {
    let stored = UserDefaults.standard.string(forKey: kSwiftDataFingerprintKey)
    guard stored != kSwiftDataSchemaFingerprint else { return }

    if let url = storeURL {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(atPath: url.path + suffix)
        }
        AppLogger.app.notice("SwiftData fingerprint changed; cleared on-disk store at \(url.path, privacy: .public)")
    }
    UserDefaults.standard.set(kSwiftDataSchemaFingerprint, forKey: kSwiftDataFingerprintKey)
}

// MARK: - Shared Container (Main App + Widget)

/// Single ModelContainer shared between the main app target and widget extension
/// via the App Group container. Failure path is belt-and-suspenders:
/// fingerprint-nuke first, store-delete-and-retry second, in-memory last resort.
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        User.self,
        Friend.self,
        Strip.self
    ])

    // CRITICAL: Point to App Group container so Widget and Main App share the same DB
    let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)?
        .appendingPathComponent("StripMate.sqlite")

    // Nuke the store BEFORE creating the container if the schema fingerprint
    // shifted — the migration validator throws NSExceptions that Swift do/catch
    // can't catch, so we have to prevent it from running in the first place.
    nukeSwiftDataStoreIfSchemaChanged(at: storeURL)

    let modelConfiguration: ModelConfiguration
    if let url = storeURL {
        modelConfiguration = ModelConfiguration(url: url)
    } else {
        modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    }

    do {
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    } catch {
        // Belt-and-suspenders: if creation still fails (e.g. fingerprint check
        // missed something), clear the store and rebuild empty.
        AppLogger.app.error("ModelContainer creation failed; deleting store and retrying: \(error.localizedDescription, privacy: .public)")

        if let url = storeURL {
            let fileManager = FileManager.default
            let storePath = url.path
            for suffix in ["", "-shm", "-wal"] {
                try? fileManager.removeItem(atPath: storePath + suffix)
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // Last resort: in-memory container so the app can still launch
            AppLogger.app.error("ModelContainer retry failed; using in-memory store: \(error.localizedDescription, privacy: .public)")
            let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }
}()
