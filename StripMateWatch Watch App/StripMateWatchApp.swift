import SwiftUI
import WatchKit

@main
struct StripMateWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchDataStore.shared)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchDataStore.shared.loadPersistedState()
        // Activate WatchConnectivity session as early as possible
        PhoneSessionManager.shared.activate()
    }
}
