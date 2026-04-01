import SwiftUI
import UIKit

// MARK: - Approach 1: UIKit navigation controller hook (works when embedded in UINavigationController)

private struct NavigationSwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        // Defer to viewDidAppear so the nav hierarchy is established
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            // Walk up to find any UINavigationController
            var responder: UIResponder? = uiViewController
            while let next = responder?.next {
                if let nav = next as? UINavigationController {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                    nav.interactivePopGestureRecognizer?.delegate = nil
                    break
                }
                responder = next
            }
        }
    }
}

// MARK: - Approach 2: Custom edge-swipe gesture that calls dismiss

struct EdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let edgeWidth: CGFloat = 30
    private let dismissThreshold: CGFloat = 100
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.86), value: dragOffset)
            .background(NavigationSwipeBackHelper()) // Also try UIKit approach
            .simultaneousGesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .onChanged { value in
                        // Only activate from left edge
                        guard value.startLocation.x < edgeWidth else { return }
                        let horizontal = value.translation.width
                        guard horizontal > 0 else { return }
                        isDragging = true
                        dragOffset = horizontal
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false
                        
                        let horizontal = value.translation.width
                        let velocity = value.predictedEndTranslation.width
                        
                        if horizontal > dismissThreshold || velocity > 500 {
                            // Animate off screen then dismiss
                            let screenWidth = UIScreen.current.bounds.width
                            dragOffset = screenWidth
                            Task {
                                try? await Task.sleep(for: .seconds(0.2))
                                dismiss()
                            }
                        } else {
                            dragOffset = 0
                        }
                    }
            )
    }
}

extension View {
    /// Enables swipe-back from the left edge when navigation bar is hidden.
    func enableSwipeBack() -> some View {
        modifier(EdgeSwipeBackModifier())
    }
}
