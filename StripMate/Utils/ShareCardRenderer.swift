import SwiftUI
import UIKit

/// Haftalik ozet paylasim kartini goruntulere donusturur ve
/// Instagram Stories / genel paylasim akislarini yonetir.
@MainActor
struct ShareCardRenderer {

    // MARK: - Render

    /// WeeklySummaryShareCard gorunumunu 1080x1920 UIImage'a donusturur.
    static func render(summary: RollcallSummary) -> UIImage? {
        let view = WeeklySummaryShareCard(summary: summary)
        let renderer = ImageRenderer(content: view.frame(width: 1080, height: 1920))
        renderer.scale = 1.0
        return renderer.uiImage
    }

    // MARK: - Instagram Stories

    /// Instagram Stories URL scheme uzerinden dogrudan hikaye paylasir.
    /// Instagram yuklu degilse sessizce basarisiz olur.
    static func shareToInstagramStories(image: UIImage) {
        guard let imageData = image.pngData() else { return }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": imageData
        ]
        UIPasteboard.general.setItems([pasteboardItems])

        if let url = URL(string: "instagram-stories://share"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Generic Share Sheet

    /// UIActivityViewController ile genel paylasim menusunu gosterir.
    /// Instagram Stories butonunu da iceren bir aksiyonla birlikte
    /// standart iOS paylasim diyalogunu acar.
    static func presentShareSheet(image: UIImage, from sourceView: UIView? = nil) {
        let activityItems: [Any] = [image]

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // iPad icin popover anchor
        if let sourceView = sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }

        // En ustteki view controller'i bul
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // Gosterme yapilacak VC'nin pencereye bagli oldugundan emin ol
        guard topVC.view.window != nil else { return }

        topVC.present(activityVC, animated: true)
    }
}
