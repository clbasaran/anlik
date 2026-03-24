import SwiftUI
import WatchKit

/// Shows the latest received photo thumbnail on the watch.
struct LatestPhotoView: View {
    @EnvironmentObject var store: WatchDataStore
    var onBack: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                // Back button
                HStack {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Ana Sayfa")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                
                if let fileURL = store.latestPhotoFileURL,
                   let imageData = try? Data(contentsOf: fileURL),
                   let uiImage = UIImage(data: imageData) {
                    photoContent(image: uiImage)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Photo Content
    
    private func photoContent(image: UIImage) -> some View {
        ZStack {
            // Full-bleed photo
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
            
            // Top gradient for legibility
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                
                Spacer()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
            }
            
            // Overlay info
            VStack {
                // Brand watermark
                HStack {
                    Spacer()
                    Text("anlık.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                
                Spacer()
                
                // Bottom info
                if let photoInfo = store.latestPhotos.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            if !photoInfo.senderName.isEmpty {
                                Text(photoInfo.senderName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            
                            if let city = photoInfo.cityName {
                                HStack(spacing: 2) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 7))
                                    Text(city)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Text(photoInfo.timestamp, style: .relative)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.2))
            
            Text("fotoğraf bekleniyor")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            
            Button {
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.3))
        }
    }
}

#Preview {
    LatestPhotoView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
