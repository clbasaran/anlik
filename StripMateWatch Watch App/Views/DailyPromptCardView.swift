import SwiftUI
import WatchKit

/// Shows today's daily photo challenge/prompt.
struct DailyPromptCardView: View {
    @EnvironmentObject var store: WatchDataStore
    var onBack: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Back button
                HStack {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Ana Sayfa")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                
                if let prompt = store.dailyPrompt {
                    promptContent(prompt)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Prompt Content
    
    private func promptContent(_ prompt: WatchPrompt) -> some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text("günün görevi")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                if prompt.isCompletedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            // Emoji
            Text(prompt.emoji)
                .font(.system(size: 36))
            
            // Prompt text
            Text(prompt.promptText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            // Action button
            if !prompt.isCompletedToday {
                Button {
                    PhoneSessionManager.shared.openCameraOnPhone()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                        Text("Çek")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            } else {
                Text("✅ Tamamlandı")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("📸")
                .font(.title2)
            
            Text("görev bekleniyor")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            
            Button {
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.3))
        }
    }
}

#Preview {
    DailyPromptCardView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
