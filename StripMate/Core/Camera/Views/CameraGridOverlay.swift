import SwiftUI

/// Rule-of-thirds grid drawn over the live preview when the user enables
/// it from the tool cluster. Lines are 0.5pt low-opacity white so they
/// guide composition without polluting the frame.
struct CameraGridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Vertical thirds
                Path { p in
                    p.move(to: CGPoint(x: w / 3, y: 0))
                    p.addLine(to: CGPoint(x: w / 3, y: h))
                    p.move(to: CGPoint(x: 2 * w / 3, y: 0))
                    p.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                }
                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

                // Horizontal thirds
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 3))
                    p.addLine(to: CGPoint(x: w, y: h / 3))
                    p.move(to: CGPoint(x: 0, y: 2 * h / 3))
                    p.addLine(to: CGPoint(x: w, y: 2 * h / 3))
                }
                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}
