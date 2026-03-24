import SwiftUI
import UIKit
import ImageIO

/// Lightweight animated GIF view using UIViewRepresentable.
/// SwiftUI's AsyncImage only renders the first frame of a GIF — this view renders all frames.
struct AnimatedGIFView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.tag = 999
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let imageView = container.viewWithTag(999) as? UIImageView else { return }
        guard container.tag != url.hashValue else { return }
        container.tag = url.hashValue
        imageView.image = nil

        guard let gifURL = URL(string: url) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: gifURL)
                let animated = Self.animatedImage(from: data)
                await MainActor.run {
                    guard container.tag == url.hashValue else { return }
                    imageView.image = animated
                }
            } catch {
                #if DEBUG
                print("AnimatedGIFView load error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - GIF Decoding

    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        var images: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let delay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (gifProps[kCGImagePropertyGIFDelayTime] as? Double)
                    ?? 0.1
                totalDuration += max(delay, 0.02)
            } else {
                totalDuration += 0.1
            }
        }

        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}
