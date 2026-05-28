import SwiftUI
import AVFoundation

/// Mini camera overlay for photo reply in strip chat.
/// Opens front camera, shows circular preview, capture + cancel.
struct PhotoReplyCapture: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var appeared = false
    @State private var showFlash = false

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
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        PhotoReplyCameraPreview()
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                            .transition(.opacity)
                    }

                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 220, height: 220)

                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                .animation(Brand.Animations.bouncy, value: appeared)

                Spacer()

                // Controls
                if capturedImage != nil {
                    // Confirm / retake
                    HStack(spacing: 40) {
                        Button {
                            HapticsManager.playSelection()
                            withAnimation(Brand.Animations.tap) {
                                capturedImage = nil
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("tekrar cek")

                        Button {
                            if let img = capturedImage {
                                HapticsManager.playNotification(type: .success)
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
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("onayla ve gönder")
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    // Shutter + cancel
                    HStack(spacing: 40) {
                        Button {
                            HapticsManager.playImpact(style: .light)
                            dismiss()
                        } label: {
                            Text("iptal")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("iptal")

                        Button {
                            capturePhoto()
                        } label: {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("fotoğraf çek")

                        // Spacer for balance
                        Text("iptal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.clear)
                            .accessibilityHidden(true)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 40)
            }
            .animation(Brand.Animations.tap, value: capturedImage != nil)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    private func capturePhoto() {
        HapticsManager.playImpact(style: .medium)

        PhotoReplyCameraManager.shared.capture { image in
            if let image {
                withAnimation(Brand.Animations.tap) {
                    self.capturedImage = image
                }
            } else {
                HapticsManager.playNotification(type: .error)
            }
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
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

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
              let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            DispatchQueue.main.async { self.completion?(nil) }
            return
        }
        // Mirror front camera
        let mirrored = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        DispatchQueue.main.async { self.completion?(mirrored) }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct PhotoReplyCameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black

        let manager = PhotoReplyCameraManager.shared
        manager.start()

        view.previewLayer.session = manager.session
        view.previewLayer.videoGravity = .resizeAspectFill

        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        PhotoReplyCameraManager.shared.stop()
    }

    /// UIView subclass that properly manages AVCaptureVideoPreviewLayer layout
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let preview = layer as? AVCaptureVideoPreviewLayer else {
                // Should never happen since layerClass is set, but avoids force unwrap crash
                AppLogger.ui.debug("AVCaptureVideoPreviewLayer cast failed — returning new layer")
                return AVCaptureVideoPreviewLayer()
            }
            return preview
        }
    }
}
