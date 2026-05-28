import SwiftUI

/// Tiny pill row that appears above the shutter when kolaj mode is active
/// AND no photos have been taken yet. Lets the user pick 2/3/4 cells before
/// firing the first shot. Once capture starts the row hides — switching
/// count mid-capture would invalidate the layout.
struct KolajCountSelector: View {
    @Binding var count: Int
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach([2, 3, 4], id: \.self) { n in
                pill(for: n)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.4)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        .background(Capsule().fill(.ultraThinMaterial).opacity(0.5))
        .clipShape(Capsule())
    }

    private func pill(for n: Int) -> some View {
        let isSelected = (n == count)
        return Button {
            guard n != count else { return }
            HapticsManager.playSelection()
            withAnimation(Brand.Animations.snap) {
                count = n
                onChange(n)
            }
        } label: {
            Text("\(n)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                .frame(width: 28, height: 22)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
