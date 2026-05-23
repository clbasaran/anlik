import SwiftUI

/// Horizontal preset chips + a trailing background-color toggle. Each chip
/// shows the preset name, a one-line subtitle, and a tiny faithful mockup
/// of the layout. Tap to apply.
struct CollagePresetBar: View {
    @Bindable var state: CollageState

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CollagePreset.allCases) { preset in
                        PresetChip(
                            preset: preset,
                            isSelected: state.preset == preset,
                            isAvailable: preset.supportedCounts.contains(state.photos.count),
                            photos: state.photos,
                            backgroundOverride: state.backgroundOverride
                        ) {
                            guard preset.supportedCounts.contains(state.photos.count) else { return }
                            HapticsManager.playSelection()
                            state.setPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            if state.preset.supportsBackgroundOverride {
                BackgroundToggle(state: state)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.preset)
    }
}

private struct PresetChip: View {
    let preset: CollagePreset
    let isSelected: Bool
    let isAvailable: Bool
    let photos: [UIImage]
    let backgroundOverride: CollagePreset.Style.SolidColor?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                MiniLayoutPreview(
                    preset: preset,
                    photos: photos,
                    backgroundOverride: backgroundOverride
                )
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.12),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )
                .shadow(color: isSelected ? .white.opacity(0.18) : .clear, radius: 8, y: 2)
                .scaleEffect(isSelected ? 1.04 : 1.0)
                VStack(spacing: 1) {
                    Text(preset.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    Text(preset.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(isSelected ? 0.55 : 0.35))
                        .lineLimit(1)
                }
                .frame(width: 70)
            }
            .opacity(isAvailable ? 1.0 : 0.3)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

/// Single segmented control: black background vs. white background. Hidden
/// for `akış` since its background is the blurred first photo.
private struct BackgroundToggle: View {
    @Bindable var state: CollageState

    var body: some View {
        let current = currentColor()
        HStack(spacing: 0) {
            segment(label: String(localized: "siyah"),
                    selected: current == .black,
                    side: .leading) {
                HapticsManager.playSelection()
                state.setBackgroundOverride(.black)
            }
            segment(label: String(localized: "beyaz"),
                    selected: current == .white,
                    side: .trailing) {
                HapticsManager.playSelection()
                state.setBackgroundOverride(.white)
            }
        }
        .frame(height: 28)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func currentColor() -> CollagePreset.Style.SolidColor? {
        if let override = state.backgroundOverride { return override }
        if case let .solid(color) = state.preset.style.background { return color }
        return nil
    }

    private enum Side { case leading, trailing }

    private func segment(label: String, selected: Bool, side: Side, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .black : .white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(selected ? Color.white : Color.clear)
                        .padding(side == .leading ? .trailing : .leading, -10)
                )
        }
        .buttonStyle(.plain)
        .frame(width: 60)
    }
}

/// Faithful preview of the preset using the user's actual photos. Each
/// chip becomes a tiny "this is exactly what your collage will look like
/// with this preset" thumbnail — far easier to compare at a glance than
/// abstract rectangles. Falls back to a neutral cell fill if no photos.
private struct MiniLayoutPreview: View {
    let preset: CollagePreset
    let photos: [UIImage]
    let backgroundOverride: CollagePreset.Style.SolidColor?

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let photoCount = photos.count
            let safeCount = preset.supportedCounts.contains(photoCount)
                ? photoCount
                : preset.supportedCounts.lowerBound
            let frames = CollageGeometry.frames(for: preset, count: safeCount, in: CGSize(width: 100, height: 144))
            let scaleX = canvas.width / 100
            let scaleY = canvas.height / 144
            let cornerRadius = preset.style.cornerRadius * (scaleX * 0.6)

            ZStack {
                background(canvas: canvas)
                ForEach(0..<frames.count, id: \.self) { (i: Int) in
                    let f = frames[i]
                    let cellW = f.width * scaleX
                    let cellH = f.height * scaleY
                    cellContent(index: i)
                        .frame(width: cellW, height: cellH)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .position(x: f.midX * scaleX, y: f.midY * scaleY)
                }
                if let divider = preset.style.divider {
                    dividerLines(frames: frames, scaleX: scaleX, scaleY: scaleY, divider: divider)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
    }

    @ViewBuilder
    private func cellContent(index i: Int) -> some View {
        if photos.indices.contains(i) {
            Image(uiImage: photos[i])
                .resizable()
                .scaledToFill()
        } else {
            Rectangle().fill(fallbackCellColor)
        }
    }

    private var bgColor: CollagePreset.Style.SolidColor? {
        if preset.supportsBackgroundOverride, let override = backgroundOverride {
            return override
        }
        if case let .solid(color) = preset.style.background { return color }
        return nil
    }

    private var fallbackCellColor: Color {
        switch bgColor {
        case .white: return Color(white: 0.3)
        case .black: return Color.white.opacity(0.7)
        case nil:    return Color.white.opacity(0.7)
        }
    }

    @ViewBuilder
    private func background(canvas: CGSize) -> some View {
        switch preset.style.background {
        case .solid:
            if bgColor == .white {
                Rectangle().fill(Color.white)
            } else {
                Rectangle().fill(Color.black)
            }
        case .blurOfFirst:
            // Real blurred first photo when available — chip then matches
            // the actual `akış` look. Falls back to gray for empty state.
            if let first = photos.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvas.width, height: canvas.height)
                    .blur(radius: 14)
                    .clipped()
                    .overlay(Color.black.opacity(0.15))
            } else {
                Rectangle().fill(Color(white: 0.35))
            }
        }
    }

    @ViewBuilder
    private func dividerLines(frames: [CGRect], scaleX: CGFloat, scaleY: CGFloat, divider: CollagePreset.Style.Divider) -> some View {
        let color: Color = divider.color == .white ? .white : .black
        ForEach(1..<frames.count, id: \.self) { (i: Int) in
            let prev = frames[i - 1]
            let curr = frames[i]
            let y = (prev.maxY + curr.minY) / 2 * scaleY
            Rectangle()
                .fill(color)
                .frame(width: prev.width * scaleX, height: 0.5)
                .position(x: prev.midX * scaleX, y: y)
        }
    }
}
