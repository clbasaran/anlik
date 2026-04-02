import SwiftUI

/// A zoomable image view that supports pinch-to-zoom and double-tap gestures.
/// Wraps around any image content and allows interactive zoom from 1x to 5x.
struct ZoomableImageView: View {
    let url: URL?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= minScale {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = minScale
                                        lastScale = minScale
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        scale > 1 ?
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 3
                                lastScale = 3
                            }
                        }
                    }
            } placeholder: {
                ProgressView().tint(.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityLabel(String(localized: "Yakınlaştırılabilir fotoğraf"))
            .accessibilityHint(String(localized: "Yakınlaştırmak için sıkıştır, çift dokunarak yakınlaştırmayı aç/kapat"))
        }
        .ignoresSafeArea(.keyboard)
    }
}
