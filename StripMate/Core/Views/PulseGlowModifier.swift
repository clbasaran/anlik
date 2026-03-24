import SwiftUI

public struct PulseGlowModifier: ViewModifier {
    @State private var isPulsing = false
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .shadow(color: Color.white.opacity(isPulsing ? 0.5 : 0.15), radius: isPulsing ? 25 : 10, y: isPulsing ? 10 : 5)
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing.toggle()
                }
            }
    }
}
