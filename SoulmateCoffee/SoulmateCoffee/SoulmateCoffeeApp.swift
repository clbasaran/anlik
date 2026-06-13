import SwiftUI

@main
struct SoulmateCoffeeApp: App {
    @StateObject private var store = DataStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.brown)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                store.persistNow()
            }
        }
    }
}
