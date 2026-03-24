import SwiftUI

/// Daily prompt banner shown in camera view
struct DailyPromptBannerView: View {
    let prompt: DailyPrompt?
    let isCompleted: Bool
    
    var body: some View {
        if let prompt = prompt {
            HStack(spacing: 10) {
                Text(prompt.emoji)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("günün görevi")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(prompt.promptText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isCompleted {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("gönderildi")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            .padding(.horizontal, 16)
        }
    }
}

/// Vertical exposure slider for camera
struct ExposureControlView: View {
    @Binding var exposureBias: Float
    let range: ClosedRange<Float>
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.yellow)
            
            // Vertical slider via rotated horizontal Slider
            Slider(value: $exposureBias, in: range, step: 0.1)
                .tint(.yellow)
                .frame(width: 120)
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 120)
            
            Button {
                HapticsManager.playImpact(style: .light)
                onReset()
            } label: {
                Text("0")
                    .font(.system(size: 12, weight: .heavy, design: .default))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(exposureBias == 0 ? Color.white.opacity(0.15) : Color.yellow.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}
