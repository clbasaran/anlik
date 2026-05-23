import SwiftUI
import AVFoundation

struct InviteCodeScannerView: View {
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionDenied {
                VStack(spacing: 16) {
                    Text("kameraya erişim gerekiyor")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("qr kod okutmak için kamera iznini açman gerekiyor.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)

                    Button("tamam") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
                }
                .padding(28)
            } else {
                ScannerPreviewRepresentable { value in
                    onCodeScanned(value)
                    dismiss()
                } onPermissionDenied: {
                    permissionDenied = true
                }
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Button("kapat") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.35), in: Capsule())

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()

                    VStack(spacing: 10) {
                        Text("arkadaşının qr kodunu okut")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text("kod okununca isteği anında göndeririz.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 42)
                }
            }
        }
    }
}

private struct ScannerPreviewRepresentable: UIViewRepresentable {
    let onCodeFound: (String) -> Void
    let onPermissionDenied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        view.configure(delegate: context.coordinator, onPermissionDenied: onPermissionDenied)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeFound: (String) -> Void
        private var hasScanned = false

        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  metadataObject.type == .qr,
                  let value = metadataObject.stringValue else { return }

            hasScanned = true
            onCodeFound(value)
        }
    }
}

private final class ScannerPreviewView: UIView {
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func configure(delegate: AVCaptureMetadataOutputObjectsDelegate, onPermissionDenied: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession(delegate: delegate)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? self.setupSession(delegate: delegate) : onPermissionDenied()
                }
            }
        default:
            onPermissionDenied()
        }
    }

    private func setupSession(delegate: AVCaptureMetadataOutputObjectsDelegate) {
        guard previewLayer == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(delegate, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.previewLayer = layer
        session.startRunning()
    }

    deinit {
        session.stopRunning()
    }
}
