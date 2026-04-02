import SwiftUI
import CoreImage.CIFilterBuiltins

/// Generates and displays QR code from user's invite code
struct QRCodeView: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(String(localized: "qr kodun"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)

                Spacer()

                // QR Code
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    // Fallback: show the code as large text if QR generation fails
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.15))
                        Text(String(localized: "qr oluşturulamadı"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 220, height: 220)
                    .padding(24)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                
                VStack(spacing: 8) {
                    Text(inviteCode)
                        .font(.system(size: 28, design: .monospaced).weight(.heavy))
                        .foregroundStyle(.white)
                        .tracking(6)
                    
                    Text(String(localized: "arkadaşın bu kodu tarayarak seni ekleyebilir"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                
                // Share button — shares QR image + invite text for WhatsApp etc.
                if let qrImage {
                    Button {
                        shareQRCode(qrImage: qrImage)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text(String(localized: "paylaş"))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
            }
            .padding(.top, 16)
        }
        .task {
            qrImage = generateQRCode(from: inviteCode)
        }
    }
    
    /// Share QR image + invite text via system share sheet (WhatsApp, iMessage, etc.)
    private func shareQRCode(qrImage: UIImage) {
        let shareText = String(localized: "Anlik'ta beni ekle!\n\nDavet kodum: \(inviteCode)\n\nQR kodu tarayarak veya kodu girerek beni ekleyebilirsin.\n\nUygulamayi indir: https://apps.apple.com/tr/app/anlik/id6759793761?l=tr")

        let items: [Any] = [shareText, qrImage]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad popover anchor
        activityVC.popoverPresentationController?.sourceView = topVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0
        )
        activityVC.popoverPresentationController?.permittedArrowDirections = []

        topVC.present(activityVC, animated: true)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        // Method 1: Modern API
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let output = filter.outputImage else {
            // Method 2: String-based fallback for older runtimes
            return generateQRCodeFallback(from: string)
        }
        
        // Scale to crisp pixel size
        let targetSize: CGFloat = 300
        let scale = targetSize / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Use a dedicated context for rendering
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return generateQRCodeFallback(from: string)
        }
        return UIImage(cgImage: cgImage)
    }
    
    /// Fallback using string-based CIFilter initialization
    private func generateQRCodeFallback(from string: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let output = filter.outputImage else { return nil }
        
        let targetSize: CGFloat = 300
        let scale = targetSize / output.extent.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = output.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
