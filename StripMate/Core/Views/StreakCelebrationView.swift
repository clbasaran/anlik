import SwiftUI

/// Full-screen streak milestone celebration overlay with confetti-like effect
struct StreakCelebrationView: View {
    let streakCount: Int
    let friendName: String
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // Confetti particles
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .animation(.easeOut(duration: particle.duration), value: particle.position)
            }
            
            // Content
            VStack(spacing: 20) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .scaleEffect(showContent ? 1.0 : 0.3)
                
                Text(String(localized: "\(streakCount) gün!"))
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(.white)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                
                Text(milestoneMessage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Text(String(localized: "sen & \(friendName)"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 8)
                
                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "harika!"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 24)
            }
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showContent = true
            }
            generateParticles()
            HapticsManager.playNotification(type: .success)
        }
    }
    
    private var milestoneMessage: String {
        switch streakCount {
        case 7: return String(localized: "bir haftalık bağ!\nbu inanılmaz bir başlangıç.")
        case 30: return String(localized: "bir aylık bağ!\nefsane ikilsiniz.")
        case 100: return String(localized: "yüz gün!\ngerçek dostluk bu.")
        case 365: return String(localized: "tam bir yıl!\nefsanesiniz.")
        default: return String(localized: "\(streakCount) gün birlikte.\ndevam edin!")
        }
    }
    
    private func generateParticles() {
        let screenWidth = UIScreen.current.bounds.width
        let screenHeight = UIScreen.current.bounds.height
        
        for i in 0..<30 {
            let particle = ConfettiParticle(
                id: i,
                position: CGPoint(x: CGFloat.random(in: 0...screenWidth), y: -20),
                size: CGFloat.random(in: 3...8),
                opacity: Double.random(in: 0.3...0.8),
                duration: Double.random(in: 2...4)
            )
            particles.append(particle)
        }
        
        // Animate particles downward
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            for i in particles.indices {
                withAnimation(.easeIn(duration: particles[i].duration)) {
                    particles[i].position.y = screenHeight + 20
                    particles[i].position.x += CGFloat.random(in: -50...50)
                }
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
    let duration: Double
}
