import SwiftUI

/// Top-right collapsible tool cluster. Default state: a single "···" pill
/// so the camera frame stays uncluttered. Tapping expands to flash,
/// timer, and grid icons stacked vertically with a soft staggered reveal
/// — premium fan motion that signals "tools are here when you need them".
struct CameraToolCluster: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isExpanded: Bool
    /// Ray-Ban Meta girişi — SDK yapılandırılamadıysa nil kalır ve satır
    /// hiç görünmez (çekirdek kamera deneyimi gözlükten bağımsız).
    var onGlasses: (() -> Void)? = nil

    var body: some View {
        // GlassEffectContainer lets the expanding tools merge and separate as
        // one continuous glass form during the stagger reveal — the exact
        // fluid morph the container API was designed for.
        GlassEffectContainer {
            VStack(alignment: .trailing, spacing: 8) {
                // Header — the toggle pill itself. Always visible.
                Button {
                    HapticsManager.playSelection()
                    withAnimation(Brand.Animations.standard) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "ellipsis")
                        .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)

                if isExpanded {
                    VStack(spacing: 8) {
                        flashTool
                            .transition(stagger(delay: 0.0))
                        timerTool
                            .transition(stagger(delay: 0.04))
                        gridTool
                            .transition(stagger(delay: 0.08))
                        if let onGlasses {
                            toolButton(
                                icon: "eyeglasses",
                                isActive: false,
                                label: String(localized: "gözlükten çek")
                            ) {
                                HapticsManager.playSelection()
                                onGlasses()
                            }
                            .transition(stagger(delay: 0.12))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tools

    private var flashTool: some View {
        toolButton(
            icon: viewModel.flashSetting.icon,
            isActive: viewModel.flashSetting != .off,
            label: viewModel.flashSetting.label
        ) {
            viewModel.toggleFlash()
        }
    }

    private var timerTool: some View {
        toolButton(
            icon: viewModel.timerSetting.icon,
            isActive: viewModel.timerSetting != .off,
            label: viewModel.timerSetting.label
        ) {
            HapticsManager.playSelection()
            viewModel.timerSetting = viewModel.timerSetting.next()
        }
    }

    private var gridTool: some View {
        toolButton(
            icon: "squareshape.split.3x3",
            isActive: viewModel.gridEnabled,
            label: viewModel.gridEnabled
                ? String(localized: "açık")
                : String(localized: "kapalı")
        ) {
            HapticsManager.playSelection()
            withAnimation(Brand.Animations.fadeFast) {
                viewModel.gridEnabled.toggle()
            }
        }
    }

    // MARK: - Helpers

    private func toolButton(icon: String, isActive: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: icon)
                    .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(isActive ? .black : .white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(isActive ? Color.white : Color.clear)
                    )
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text(label))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private func stagger(delay: Double) -> AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.85, anchor: .top))
                .animation(.spring(response: 0.35, dampingFraction: 0.78).delay(delay)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}
