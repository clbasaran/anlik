import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Full-screen QR overlay shown from FriendGate when the user taps "QR'ı
/// göster". Generates the code locally so we don't burn a Firestore read or
/// network round trip just to render a string the user already has on device.
struct FriendGateQROverlay: View {
    let inviteCode: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Text(String(localized: "qr kodun"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                if let qrImage = Self.generateQRCode(from: inviteCode) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                Text(inviteCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityLabel(String(localized: "davet kodu \(inviteCode)"))

                Text(String(localized: "arkadaşın bu kodu tarasın veya girsin"))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))

                Button {
                    HapticsManager.playImpact(style: .light)
                    onDismiss()
                } label: {
                    Text(String(localized: "kapat"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }

    /// Local CIFilter-based QR generator. Static so the same routine is
    /// reusable from places that want a UIImage directly (e.g. share sheet
    /// or QR widget) without instantiating the overlay.
    static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    FriendGateQROverlay(inviteCode: "ABCD1234", onDismiss: {})
}
