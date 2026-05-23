import SwiftUI

/// Top-right collapsible tool cluster. Default state: a single "···" pill
/// so the camera frame stays uncluttered. Tapping expands to flash,
/// timer, and grid icons stacked vertically with a soft staggered reveal
/// — premium fan motion that signals "tools are here when you need them".
struct CameraToolCluster: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Header — the toggle pill itself. Always visible.
            Button {
                HapticsManager.playSelection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    flashTool
                        .transition(stagger(delay: 0.0))
                    timerTool
                        .transition(stagger(delay: 0.04))
                    gridTool
                        .transition(stagger(delay: 0.08))
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
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.gridEnabled.toggle()
            }
        }
    }

    // MARK: - Helpers

    private func toolButton(icon: String, isActive: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isActive ? .black : .white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(isActive ? Color.white : Color.black.opacity(0.001))
                    )
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .accessibilityLabel(Text(label))
        }
        .buttonStyle(.plain)
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
