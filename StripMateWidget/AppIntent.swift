//
//  AppIntent.swift
//  StripMateWidget
//
//  Created by Celal Başaran on 26.02.2026.
//

import Foundation
import AppIntents

/// Interactive widget intent: opens the app directly to camera
struct OpenCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "Kamerayı Aç"
    static var description = IntentDescription("anlık. kamerasını açar")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        defaults?.set(true, forKey: "pending_camera_launch")
        return .result()
    }
}
