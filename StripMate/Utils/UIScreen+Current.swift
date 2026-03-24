import UIKit

extension UIScreen {
    /// Replacement for the deprecated `UIScreen.main` in iOS 26+.
    /// Resolves the current screen from the active window scene.
    static var current: UIScreen {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen ?? UIScreen()
    }
}
