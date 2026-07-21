import SwiftUI
import LockedCameraCapture

// Lock Screen capture extension (iPhone 16+ Camera Control, Action button,
// Lock Screen camera widget). Runs while the device is locked, so it has no
// access to app state, Firebase, or the shared App Group — captured photos go
// into the session's content directory and the main app imports them on next
// unlock via LockedCameraCaptureManager.

@main
struct StripMateLockedCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCaptureView(session: session)
        }
    }
}
