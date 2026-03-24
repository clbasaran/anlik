import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct LaunchCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "Kamerayı Aç"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Communicate with the app via App Group
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        sharedDefaults?.set(true, forKey: "pending_camera_launch")
        
        return .result()
    }
}

@available(iOS 18.0, *)
struct StripMateControls: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.celalbasaran.stripmate.camera-control") {
            ControlWidgetButton(action: LaunchCameraIntent()) {
                Label("Kamera", systemImage: "camera.fill")
            }
        }
        .displayName("StripMate Kamera")
        .description("Kamerayı hızlıca aç.")
    }
}
