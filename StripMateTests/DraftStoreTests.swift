import Testing
import UIKit
@testable import StripMate

/// DraftStore is the single guardrail against losing a user's photo to a
/// network blip or process kill — and it is single-slot, so overwrite and
/// clear semantics matter as much as the roundtrip. Serialized because every
/// instance shares one on-disk slot.
@Suite("DraftStore", .serialized)
struct DraftStoreTests {

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private func withCleanSlot(_ body: (DraftStore) throws -> Void) rethrows {
        let store = DraftStore()
        store.clear()
        defer { store.clear() }
        try body(store)
    }

    @Test("empty slot restores nil")
    func emptySlotRestoresNil() {
        withCleanSlot { store in
            #expect(store.restore() == nil)
            #expect(store.hasDraft == false)
        }
    }

    @Test("photo draft roundtrips metadata and image")
    func photoDraftRoundtrip() {
        withCleanSlot { store in
            store.save(
                receivers: ["friend1", "friend2"],
                comment: "test yorumu",
                latitude: 41.0,
                longitude: 29.0,
                cityName: "istanbul",
                isSecret: true,
                videoDuration: nil,
                videoIncludesSound: true,
                image: makeImage()
            )
            let restored = store.restore()
            #expect(restored != nil)
            #expect(restored?.snapshot.receivers == ["friend1", "friend2"])
            #expect(restored?.snapshot.comment == "test yorumu")
            #expect(restored?.snapshot.cityName == "istanbul")
            #expect(restored?.snapshot.isSecret == true)
            #expect(restored?.image != nil)
            #expect(restored?.snapshot.awaitingFirstFriend == nil)
        }
    }

    @Test("second save replaces the slot")
    func saveReplacesSlot() {
        withCleanSlot { store in
            store.save(receivers: ["a"], comment: "ilk", latitude: nil, longitude: nil,
                       cityName: nil, isSecret: false, videoDuration: nil,
                       videoIncludesSound: true, image: makeImage())
            store.save(receivers: ["b"], comment: "ikinci", latitude: nil, longitude: nil,
                       cityName: nil, isSecret: false, videoDuration: nil,
                       videoIncludesSound: true, image: makeImage())
            let restored = store.restore()
            #expect(restored?.snapshot.receivers == ["b"])
            #expect(restored?.snapshot.comment == "ikinci")
        }
    }

    @Test("clear removes metadata and media")
    func clearEmptiesSlot() {
        withCleanSlot { store in
            store.save(receivers: ["a"], comment: nil, latitude: nil, longitude: nil,
                       cityName: nil, isSecret: false, videoDuration: nil,
                       videoIncludesSound: true, image: makeImage())
            #expect(store.hasDraft == true)
            store.clear()
            #expect(store.hasDraft == false)
            #expect(store.restore() == nil)
        }
    }

    @Test("awaitingFirstFriend flag roundtrips")
    func firstFriendFlagRoundtrip() {
        withCleanSlot { store in
            store.save(receivers: [], comment: nil, latitude: nil, longitude: nil,
                       cityName: nil, isSecret: false, videoDuration: nil,
                       videoIncludesSound: true, image: makeImage(),
                       awaitingFirstFriend: true)
            #expect(store.restore()?.snapshot.awaitingFirstFriend == true)
        }
    }

    @Test("voice data survives the roundtrip")
    func voiceRoundtrip() {
        withCleanSlot { store in
            let voice = Data([0x01, 0x02, 0x03, 0x04])
            store.save(receivers: ["a"], comment: nil, latitude: nil, longitude: nil,
                       cityName: nil, isSecret: false, videoDuration: nil,
                       videoIncludesSound: true, image: makeImage(), voiceData: voice)
            let restored = store.restore()
            #expect(restored?.snapshot.hasVoice == true)
            #expect(restored?.voiceData == voice)
        }
    }
}

/// The store catalog is a contract with App Store Connect: IDs must stay
/// unique and follow the bundle-id convention, or purchases silently fail to
/// resolve once the products are created.
@Suite("StoreService catalog")
struct StoreCatalogTests {

    @Test("product ids are unique")
    @MainActor
    func idsUnique() {
        let ids = StoreService.Catalog.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
    }

    @Test("product ids follow the bundle-id prefix convention")
    @MainActor
    func idsPrefixed() {
        for c in StoreService.Catalog.allCases {
            #expect(c.rawValue.hasPrefix("com.celalbasaran.stripmate."))
        }
    }
}
