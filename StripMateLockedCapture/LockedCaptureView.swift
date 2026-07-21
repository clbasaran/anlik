import SwiftUI
import AVFoundation
import LockedCameraCapture

/// Minimal, self-contained capture surface for the locked context. Mirrors the
/// app's monochrome language: black canvas, white ring shutter, lowercase copy.
/// No Firebase, no App Group — the only output is JPEG files written to
/// `session.sessionContentURL`, which the app imports after unlock.
struct LockedCaptureView: View {
    let session: LockedCameraCaptureSession

    @State private var camera = LockedCaptureCameraModel()
    @State private var savedCount = 0
    @State private var showSavedFlash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LockedCameraPreview(session: camera.captureSession)
                .ignoresSafeArea()

            VStack {
                Spacer()

                if showSavedFlash {
                    Text("kaydedildi. göndermek için kilidi aç.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                        .transition(.opacity)
                        .padding(.bottom, 12)
                }

                HStack {
                    Spacer()
                        .frame(maxWidth: .infinity)

                    // Shutter — white ring, same geometry as the in-app shutter.
                    Button {
                        camera.capturePhoto { data in
                            guard let data else { return }
                            let url = session.sessionContentURL
                                .appendingPathComponent("capture_\(savedCount)_\(Int(Date().timeIntervalSince1970)).jpg")
                            try? data.write(to: url, options: .atomic)
                            savedCount += 1
                            withAnimation(.easeInOut(duration: 0.25)) { showSavedFlash = true }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                withAnimation(.easeInOut(duration: 0.25)) { showSavedFlash = false }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 78, height: 78)
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("fotoğraf çek")

                    // Flip camera
                    HStack {
                        Spacer()
                        Button {
                            camera.flipCamera()
                        } label: {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.white.opacity(0.12), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("kamerayı çevir")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 28)
            }
        }
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

// MARK: - Camera model

@MainActor
@Observable
final class LockedCaptureCameraModel: NSObject {
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var completion: ((Data?) -> Void)?

    func start() async {
        var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if !authorized {
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard authorized else { return }
        configure(position: currentPosition)
        let session = captureSession
        Task.detached { session.startRunning() }
    }

    func stop() {
        let session = captureSession
        Task.detached { session.stopRunning() }
    }

    func flipCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        configure(position: currentPosition)
    }

    private func configure(position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        if !captureSession.outputs.contains(photoOutput), captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension LockedCaptureCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            self.completion?(error == nil ? data : nil)
            self.completion = nil
        }
    }
}

// MARK: - Preview layer

private struct LockedCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}

    final class PreviewHostView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
