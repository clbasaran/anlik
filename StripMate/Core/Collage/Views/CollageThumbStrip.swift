import SwiftUI

/// Horizontal strip of photo thumbnails with drag-to-reorder + tap/long-press.
/// Tap selects a thumb (focuses its cell on the preview); long-press opens
/// the per-photo action menu. Trailing "+" appears below the cap of 4.
struct CollageThumbStrip: View {
    @Bindable var state: CollageState
    let onAddTap: () -> Void
    let onPhotoTap: (Int) -> Void
    let onPhotoLongPress: (Int) -> Void

    @State private var draggingIndex: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<state.photos.count, id: \.self) { (i: Int) in
                    thumbView(index: i)
                }

                if state.photos.count < state.preset.supportedCounts.upperBound,
                   state.photos.count < 4 {
                    addButton
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func thumbView(index i: Int) -> some View {
        let img = state.photos[i]
        let isFocused = state.focusedIndex == i
        let isDragging = draggingIndex == i
        return Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white :
                            (isDragging ? Color.white.opacity(0.6) : Color.white.opacity(0.08)),
                        lineWidth: isFocused ? 2 : (isDragging ? 1.5 : 0.5)
                    )
            )
            .scaleEffect(isDragging ? 1.08 : (isFocused ? 1.04 : 1.0))
            .animation(Brand.Animations.tap, value: draggingIndex)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: state.focusedIndex)
            .onTapGesture {
                onPhotoTap(i)
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                HapticsManager.playImpact(style: .medium)
                onPhotoLongPress(i)
            }
            .onDrag {
                draggingIndex = i
                return NSItemProvider(object: NSString(string: "\(i)"))
            }
            .onDrop(of: [.text], delegate: ReorderDropDelegate(
                destinationIndex: i,
                state: state,
                draggingIndex: $draggingIndex
            ))
    }

    private var addButton: some View {
        Button {
            HapticsManager.playImpact(style: .light)
            onAddTap()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let destinationIndex: Int
    let state: CollageState
    @Binding var draggingIndex: Int?

    func performDrop(info: DropInfo) -> Bool {
        if let from = draggingIndex, from != destinationIndex {
            state.swap(from, destinationIndex)
            HapticsManager.playSelection()
        }
        draggingIndex = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let from = draggingIndex, from != destinationIndex else { return }
        // Live preview: swap as the user hovers, so the strip animates the
        // reorder before the drop completes. The final commit on
        // performDrop is then a no-op when it lands on the same position.
        state.swap(from, destinationIndex)
        draggingIndex = destinationIndex
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
