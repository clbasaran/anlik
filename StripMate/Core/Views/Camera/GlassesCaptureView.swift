import SwiftUI

/// Ray-Ban Meta vizörü: gözlük kamerasından canlı akış + beyaz halka
/// deklanşör. Yakalanan kare sheet'i kapatıp normal önizleme/gönderim
/// akışına düşer — gözlük sadece yeni bir "göz", boru hattı aynı.
struct GlassesCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var glasses = MetaGlassesService.shared
    /// Yakalanan JPEG verisi kamera akışına bu closure ile teslim edilir.
    let onCapture: (Data) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch glasses.phase {
            case .streaming:
                viewfinder
            case .connecting:
                statusView(
                    icon: "eyeglasses",
                    text: String(localized: "gözlüğe bağlanılıyor…"),
                    showSpinner: true
                )
            case .failed(let message):
                VStack(spacing: 16) {
                    statusView(icon: "eyeglasses.slash", text: message, showSpinner: false)
                    retryButton
                }
            case .idle:
                if glasses.isRegistered {
                    statusView(icon: "eyeglasses", text: String(localized: "başlatılıyor…"), showSpinner: true)
                } else {
                    registrationPrompt
                }
            }

            // Kapat
            VStack {
                HStack {
                    CircleIconButton(icon: "xmark", accessibilityLabel: "kapat") {
                        glasses.stopStreaming()
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                Spacer()
            }
        }
        .task {
            if glasses.isRegistered {
                await glasses.startStreaming()
            }
        }
        .onChange(of: glasses.isRegistered) { _, registered in
            if registered {
                Task { await glasses.startStreaming() }
            }
        }
        .onChange(of: glasses.capturedPhotoData) { _, data in
            guard let data else { return }
            glasses.capturedPhotoData = nil
            glasses.stopStreaming()
            onCapture(data)
            dismiss()
        }
        .onDisappear {
            glasses.stopStreaming()
        }
    }

    // MARK: - Katmanlar

    private var viewfinder: some View {
        ZStack {
            if let frame = glasses.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(String(localized: "gözlük kamerası canlı görüntüsü"))
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                Spacer()
                Button {
                    HapticsManager.playImpact(style: .medium)
                    glasses.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                            .opacity(glasses.isCapturingPhoto ? 0.5 : 1)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(glasses.isCapturingPhoto)
                .accessibilityLabel(String(localized: "gözlükten fotoğraf çek"))
                .padding(.bottom, 40)
            }
        }
    }

    private var registrationPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text(String(localized: "gözlüğünü bağla"))
                .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(.white)
            Text(String(localized: "ray-ban meta gözlüğünle an yakalamak için meta ai üzerinden bir kez eşleştirme gerekiyor."))
                .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await glasses.startRegistration() }
            } label: {
                Text(String(localized: "meta ai ile bağla"))
                    .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func statusView(icon: String, text: String, showSpinner: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text(text)
                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if showSpinner {
                ProgressView().tint(.white.opacity(0.6))
            }
        }
    }

    private var retryButton: some View {
        Button {
            Task { await glasses.startStreaming() }
        } label: {
            Text(String(localized: "tekrar dene"))
                .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(.white, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
