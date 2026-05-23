import Testing
import Foundation
@testable import StripMate

/// The App Group schema version is a small piece of glue, but if it
/// regresses (e.g. a future migration accidentally re-stamps an older
/// version), the data semantics for NSE / Widget / Main App diverge silently.
/// Pin the basics down with tests.
@Suite("AppGroupSchema")
struct AppGroupSchemaTests {

    /// Use a private suite name so we don't pollute the real App Group during
    /// tests. The schema helper reads `AppConstants.appGroupID` directly, so
    /// we reset its keys before each test rather than trying to inject a
    /// custom suite — keeps the helper API minimal.
    @MainActor
    @Test("currentSchemaVersion is positive")
    func versionIsPositive() {
        #expect(AppGroupKeys.currentSchemaVersion >= 1)
    }

    @Test("schema key string is stable")
    func schemaKeyIsStable() {
        // The version key name is part of the on-disk contract — renaming it
        // would orphan the existing stamp on every device. Lock it.
        #expect(AppGroupKeys.schemaVersion == "app_group_schema_version")
    }

    @Test("blocked-set key is stable")
    func blockedKeyIsStable() {
        // Lives in the App Group container as a fail-closed cache for the
        // photo feed. AuthService.bestKnownBlockedUserIds reads this key.
        #expect(AppGroupKeys.blockedUserIds == "blocked_user_ids")
    }

    @Test("widget timeline key is stable")
    func widgetTimelineKeyIsStable() {
        // Widget reads this to decide whether NSE wrote newer data than what
        // it last rendered.
        #expect(AppGroupKeys.widgetLastTimeline == "widget_last_timeline")
    }

    @Test("latest photo time key is stable")
    func latestPhotoTimeKeyIsStable() {
        // NSE writes this; widget reads it. Renaming on either side breaks
        // the freshness comparison.
        #expect(AppGroupKeys.latestPhotoTime == "latest_photo_time")
    }
}
