import SwiftUI

/// Two-segment mode picker. The selected mode is full-white bold text on a
/// subtle white-tinted capsule that slides between options via
/// `matchedGeometryEffect`. Deliberately NOT a solid white fill: on the camera
/// deck pure white belongs to the shutter alone, and a translucent indicator
/// stays legible over both bright and dark scenes. Typography is lowercase
/// with modest tracking to feel premium and quiet rather than chrome-y.
struct CameraModePicker: View {
    @Binding var mode: CameraMode
    var disabled: Bool = false

    @Namespace private var indicator
    private let segmentSize = CGSize(width: 86, height: 28)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CameraMode.allCases) { m in
                segment(for: m)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.32))
        )
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .opacity(disabled ? 0.4 : 1.0)
        .allowsHitTesting(!disabled)
    }

    @ViewBuilder
    private func segment(for m: CameraMode) -> some View {
        let isSelected = (m == mode)
        Button {
            guard m != mode else { return }
            HapticsManager.playSelection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                mode = m
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .matchedGeometryEffect(id: "selected", in: indicator)
                }
                Text(m.displayName)
                    .font(Brand.scaledFont(size: 12.5, weight: isSelected ? .bold : .semibold, relativeTo: .caption))
                    .tracking(0.4)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
            }
            .frame(width: segmentSize.width, height: segmentSize.height)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
