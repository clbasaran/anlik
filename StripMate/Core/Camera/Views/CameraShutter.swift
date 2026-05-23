import SwiftUI

/// The shutter button. Single visual element that morphs based on the
/// current capture mode and recording state. Outer ring stays constant
/// (visual anchor); inner content swaps with a soft cross-dissolve.
///
/// - foto  : clean white disc (long-press = video, handled by caller)
/// - kolaj : white disc with a small "1/N" counter
///
/// Pure visual. The gesture (tap vs long-press, video recording) lives in
/// MainCameraView so the existing shutter-press logic isn't disturbed.
struct CameraShutter: View {
    let mode: CameraMode
    let isRecordingVideo: Bool
    let videoRecordingProgress: Double
    /// Kolaj mode only: how many photos the user has taken so far + the
    /// total target. Used to draw the "1/3" counter inside the disc.
    let kolajCaptured: Int
    let kolajTarget: Int

    var body: some View {
        ZStack {
            // Recording progress ring — only visible during video.
            if isRecordingVideo {
                Circle()
                    .trim(from: 0, to: videoRecordingProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: videoRecordingProgress)
            }

            // Outer ring — constant anchor across modes.
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                .frame(width: 78, height: 78)

            // Inner disc + content.
            ZStack {
                Circle()
                    .fill(isRecordingVideo ? Color.red : Color.white)
                    .frame(
                        width: isRecordingVideo ? 72 : 62,
                        height: isRecordingVideo ? 72 : 62
                    )

                if !isRecordingVideo {
                    innerContent
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isRecordingVideo)
            .animation(.easeInOut(duration: 0.22), value: mode)
        }
    }

    @ViewBuilder
    private var innerContent: some View {
        switch mode {
        case .foto:
            // No glyph — clean disc reads as "tap to capture".
            EmptyView()
        case .kolaj:
            // "1/3" — current cell out of target. Numeric monospace so the
            // glyph doesn't reflow as digits change.
            Text("\(kolajCaptured + 1)/\(kolajTarget)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
        }
    }
}
