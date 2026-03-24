import SwiftUI
import PhotosUI

// MARK: - Avatar Photo Picker

/// Photo picker for avatar uploads — after selection, presents a crop overlay, then delivers a UIImage.
struct AvatarPhotoPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: AvatarPhotoPicker
        init(_ parent: AvatarPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    Task { @MainActor in
                        // Dismiss the picker, then show the cropper
                        picker.dismiss(animated: true) {
                            self.presentCropper(with: image, from: picker)
                        }
                    }
                } else {
                    Task { @MainActor in
                        self.parent.dismiss()
                    }
                }
            }
        }

        @MainActor
        private func presentCropper(with image: UIImage, from picker: PHPickerViewController) {
            // Find the top-most presented view controller to present the cropper
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else {
                // Fallback: deliver image uncropped
                parent.onImageSelected(image)
                return
            }

            var topVC = root
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            let cropperView = ImageCropperView(image: image) { croppedImage in
                self.parent.onImageSelected(croppedImage)
            }
            let hostingVC = UIHostingController(rootView: cropperView)
            hostingVC.modalPresentationStyle = .fullScreen
            hostingVC.view.backgroundColor = .black
            topVC.present(hostingVC, animated: true)
        }
    }
}
