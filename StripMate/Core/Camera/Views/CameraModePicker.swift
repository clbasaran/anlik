import SwiftUI

/// Two-segment mode picker. Selected mode draws a white capsule that
/// slides between options via `matchedGeometryEffect` — no fade, no
/// re-paint, just a single shape moving. Typography is lowercase with
/// modest tracking to feel premium and quiet rather than chrome-y.
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
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
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
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "selected", in: indicator)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                }
                Text(m.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.62))
            }
            .frame(width: segmentSize.width, height: segmentSize.height)
        }
        .buttonStyle(.plain)
    }
}
