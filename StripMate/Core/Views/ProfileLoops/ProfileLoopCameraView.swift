import SwiftUI
import AVFoundation
import UIKit

/// In-app camera for recording short (≤ 2 second) profile loops.
/// Press-and-hold or tap to record. Hands the resulting local video URL back
/// via `onCaptured` and dismisses.
public struct ProfileLoopCameraView: View {
    let onCaptured: (URL) -> Void
    let onCancel: () -> Void

    public static let maxDuration: TimeInterval = 2.0

    @StateObject private var recorder = ProfileLoopCameraRecorder()
    @State private var progress: Double = 0
    @State private var progressTimer: Task<Void, Never>?

    public init(onCaptured: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onCaptured = onCaptured
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview layer
            CameraPreview(session: recorder.session)
                .ignoresSafeArea()
                .opacity(recorder.isReady ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: recorder.isReady)

            if !recorder.isReady {
                ProgressView().tint(.white)
            }

            VStack {
                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    Spacer()
                    Text(String(localized: "2 saniyelik klip"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                    Button {
                        recorder.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Record button with progress ring
                ZStack {
                    // Outer progress ring
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 4)
                        .frame(width: 96, height: 96)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                        .animation(.linear(duration: 0.05), value: progress)

                    // Inner record dot
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.white)
                        .frame(width: recorder.isRecording ? 38 : 72,
                               height: recorder.isRecording ? 38 : 72)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7),
                                   value: recorder.isRecording)
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.05)
                        .onChanged { _ in
                            startRecording()
                        }
                )
                .onTapGesture {
                    if recorder.isRecording {
                        Task { await stopAndDeliver() }
                    } else {
                        startRecording()
                    }
                }
                .accessibilityLabel(String(localized: "Profil hareketi kaydet"))
                .accessibilityHint(String(localized: "Basılı tut, en fazla 2 saniye"))

                Text(String(localized: "basılı tut, otomatik durur"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 16)

                Spacer().frame(height: 36)
            }
        }
        .task {
            await recorder.prepare()
        }
        .onDisappear {
            recorder.stopAndDiscard()
            progressTimer?.cancel()
        }
    }

    // MARK: - Recording control

    private func startRecording() {
        guard !recorder.isRecording, recorder.isReady else { return }
        progress = 0
        recorder.startRecording()
        HapticsManager.playImpact(style: .heavy)

        // Drive the progress ring + auto-stop at 2s
        progressTimer?.cancel()
        progressTimer = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled, recorder.isRecording {
                let elapsed = Date().timeIntervalSince(start)
                progress = min(elapsed / Self.maxDuration, 1.0)
                if elapsed >= Self.maxDuration {
                    await stopAndDeliver()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
    }

    private func stopAndDeliver() async {
        progressTimer?.cancel()
        progressTimer = nil
        if let url = await recorder.stopRecording() {
            HapticsManager.playNotification(type: .success)
            onCaptured(url)
        } else {
            // Failed — leave UI to user
            progress = 0
        }
    }
}

// MARK: - AVFoundation recorder

@MainActor
final class ProfileLoopCameraRecorder: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isRecording = false

    let session = AVCaptureSession()
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .front
    private var stopContinuation: CheckedContinuation<URL?, Never>?
    private var lastOutputURL: URL?

    func prepare() async {
        // Authorization
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { return }
        } else if status != .authorized {
            return
        }

        await Task.detached(priority: .userInitiated) { [self] in
            await configureSession()
        }.value
    }

    private nonisolated func configureSession() async {
        await MainActor.run { [self] in
            session.beginConfiguration()
            session.sessionPreset = .high

            // Remove old inputs/outputs
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            // Camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            currentInput = input

            // Mic (audio)
            if let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(micInput) {
                session.addInput(micInput)
            }

            // Movie output
            let output = AVCaptureMovieFileOutput()
            // Cap to ~2.5 sec hardware-side as a safety net (we also stop manually)
            output.maxRecordedDuration = CMTime(seconds: 2.5, preferredTimescale: 600)
            if session.canAddOutput(output) {
                session.addOutput(output)
                movieOutput = output
            }

            // Apply video stabilization + mirror (front camera) to the active
            // video connection. Stabilization smooths out camera shake;
            // mirroring ensures the captured selfie matches the live preview
            // (otherwise text/right-side appears reversed in the saved file).
            if let connection = output.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                if currentPosition == .front && connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
            }

            session.commitConfiguration()

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    self?.isReady = true
                }
            }
        }
    }

    func toggleCamera() {
        currentPosition = (currentPosition == .front) ? .back : .front
        Task.detached { [self] in
            await configureSession()
        }
    }

    func startRecording() {
        guard let output = movieOutput, !output.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("loop_record_\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: url)
        lastOutputURL = url
        output.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    /// Stops recording and returns the resulting local file URL (or nil on failure).
    func stopRecording() async -> URL? {
        guard let output = movieOutput, output.isRecording else { return lastOutputURL }
        return await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            self.stopContinuation = continuation
            output.stopRecording()
        }
    }

    /// Cancel recording without delivering a URL — used on view disappear.
    func stopAndDiscard() {
        if let output = movieOutput, output.isRecording {
            output.stopRecording()
        }
        if session.isRunning {
            session.stopRunning()
        }
        stopContinuation?.resume(returning: nil)
        stopContinuation = nil
    }
}

extension ProfileLoopCameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: (any Error)?) {
        Task { @MainActor in
            self.isRecording = false
            // Apple delivers the file even when maxRecordedDuration hits — that's success
            // for our purposes. Real errors return the file but with a non-nil error.
            // We accept the file regardless if it's > 0 bytes.
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)
            let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
            let url: URL? = size > 0 ? outputFileURL : nil
            self.stopContinuation?.resume(returning: url)
            self.stopContinuation = nil
        }
    }
}

// MARK: - Camera preview layer

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
