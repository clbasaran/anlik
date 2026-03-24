import SwiftUI

public struct MeshGradientBackground: View {
    @State private var animate = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Brand.meshBase // Deep OLED-black base
                .ignoresSafeArea()
            
            // Orb 1 — warm charcoal glow (top-left drift)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Brand.meshOrb1, Brand.meshOrb1.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: animate ? -120 : 140, y: animate ? -220 : 20)
            
            // Orb 2 — cool slate glow (bottom-right drift)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Brand.meshOrb2, Brand.meshOrb2.opacity(0.3)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: animate ? 160 : -110, y: animate ? 220 : 80)
            
            // Subtle accent kiss — very faint lilac highlight
            Circle()
                .fill(Brand.accent.opacity(0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: animate ? 50 : -50, y: animate ? -80 : 60)
        }
        .drawingGroup() // Metal-accelerated compositing for blurred animated layers
        .onAppear {
            withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
