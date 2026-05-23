import SwiftUI

/// Displays up to 3 profile loops in a row. Empty slots show a placeholder
/// (with a "+" if `editable` is true). Tapping a slot fires `onSlotTapped`.
public struct ProfileLoopGalleryView: View {
    let loops: [ProfileLoop]
    let editable: Bool
    let onSlotTapped: ((Int) -> Void)?

    public init(
        loops: [ProfileLoop],
        editable: Bool = false,
        onSlotTapped: ((Int) -> Void)? = nil
    ) {
        self.loops = loops
        self.editable = editable
        self.onSlotTapped = onSlotTapped
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<ProfileLoopService.maxSlots, id: \.self) { slot in
                slotView(for: slot)
            }
        }
    }

    @ViewBuilder
    private func slotView(for slot: Int) -> some View {
        let loop = loops.first(where: { $0.slot == slot })

        Button {
            onSlotTapped?(slot)
        } label: {
            ZStack {
                if let loop {
                    ProfileLoopPlayerView(loop: loop, cornerRadius: 14, aspectRatio: 3 / 4)
                } else {
                    emptySlot
                }
            }
            .aspectRatio(3 / 4, contentMode: .fill)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(onSlotTapped == nil)
        .accessibilityLabel(
            loop == nil
                ? String(localized: "Profil hareketi ekle, slot \(slot + 1)")
                : String(localized: "Profil hareketi \(slot + 1)")
        )
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .overlay {
                if editable {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(String(localized: "ekle"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.20))
                }
            }
    }
}
