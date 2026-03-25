import SwiftUI
import AVFoundation

/// Mini camera overlay for photo reply in strip chat.
/// Opens front camera, shows circular preview, capture + cancel.
struct PhotoReplyCapture: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Preview circle
                ZStack {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                    } else {
                        PhotoReplyCameraPreview()
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                    }

                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 220, height: 220)
                }

                Spacer()

                // Controls
                if capturedImage != nil {
                    // Confirm / retake
                    HStack(spacing: 40) {
                        Button {
                            capturedImage = nil
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Button {
                            if let img = capturedImage {
                                onCapture(img)
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 64, height: 64)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                } else {
                    // Shutter + cancel
                    HStack(spacing: 40) {
                        Button {
                            dismiss()
                        } label: {
                            Text("iptal")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Button {
                            capturePhoto()
                        } label: {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }

                        // Spacer for balance
                        Text("iptal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.clear)
                    }
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
    }

    private func capturePhoto() {
        PhotoReplyCameraManager.shared.capture { image in
            self.capturedImage = image
        }
    }
}

// MARK: - Camera Manager (simplified front camera only)

final class PhotoReplyCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    static let shared = PhotoReplyCameraManager()
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?
    private var isConfigured = false

    func configure() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        isConfigured = true
    }

    func start() {
        configure()
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    func stop() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.completion?(nil) }
            return
        }
        // Mirror front camera
        let mirrored = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
        DispatchQueue.main.async { self.completion?(mirrored) }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct PhotoReplyCameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let manager = PhotoReplyCameraManager.shared
        manager.start()

        let previewLayer = AVCaptureVideoPreviewLayer(session: manager.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        if let previewLayer = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = view.bounds
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: ()) {
        PhotoReplyCameraManager.shared.stop()
    }
}
