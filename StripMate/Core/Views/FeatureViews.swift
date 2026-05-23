import SwiftUI
import Combine

// MARK: - Typing Indicator View (P1)

/// Animated "..." typing bubble shown when the partner is typing
struct TypingIndicatorView: View {
    @State private var dotIndex = 0
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(dotIndex == index ? 1.3 : 0.8)
                    .opacity(dotIndex == index ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 0.3), value: dotIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onReceive(timer) { _ in
            dotIndex = (dotIndex + 1) % 3
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Yazıyor"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Friendship Tier-Up Celebration (P1)

/// Overlay shown when a friendship tier changes (e.g. casual → close friend)
struct TierUpCelebrationView: View {
    let fromTier: Streak.FriendshipTier
    let toTier: Streak.FriendshipTier
    let friendName: String
    let onDismiss: () -> Void
    
    @State private var appeared = false
    @State private var particles: [CelebrationParticle] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // Particles
            ForEach(particles) { particle in
                Image(systemName: particle.icon)
                    .font(.system(size: particle.size, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .position(particle.position)
                    .opacity(appeared ? 0 : 1)
                    .animation(.easeOut(duration: 2.5).delay(particle.delay), value: appeared)
            }
            
            VStack(spacing: 24) {
                // Tier icon — large, bouncing
                Image(systemName: toTier.tierIcon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1.0 : 0.01)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5), value: appeared)
                
                VStack(spacing: 8) {
                    Text(String(localized: "seviye atladınız!"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(2)
                    
                    Text(toTier.tierName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(friendName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: appeared)
                
                // Progress indicator
                HStack(spacing: 8) {
                    Image(systemName: fromTier.tierIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.gray)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Image(systemName: toTier.tierIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
            }
        }
        .onAppear {
            generateParticles()
            withAnimation { appeared = true }
            // Auto-dismiss after 3s
            Task {
                try? await Task.sleep(for: .seconds(3.0))
                onDismiss()
            }
        }
    }
    
    private func generateParticles() {
        let screen = UIScreen.current.bounds
        let icons = [toTier.tierIcon, "sparkle", "star.fill", "circle.fill"]
        particles = (0..<20).map { _ in
            CelebrationParticle(
                id: UUID(),
                icon: icons.randomElement() ?? "sparkle",
                position: CGPoint(
                    x: CGFloat.random(in: 20...screen.width - 20),
                    y: CGFloat.random(in: 100...screen.height - 100)
                ),
                size: CGFloat.random(in: 10...22),
                delay: Double.random(in: 0...0.5)
            )
        }
    }
}

struct CelebrationParticle: Identifiable {
    let id: UUID
    let icon: String
    let position: CGPoint
    let size: CGFloat
    let delay: Double
}

// MARK: - Shutter Iris Animation (P3)

/// Iris-close animation on photo capture
struct ShutterIrisView: View {
    @Binding var isActive: Bool
    
    var body: some View {
        if isActive {
            Circle()
                .fill(Color.white)
                .scaleEffect(isActive ? 0.01 : 3.0)
                .opacity(isActive ? 0 : 1)
                .animation(.easeIn(duration: 0.25), value: isActive)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        isActive = false
                    }
                }
        }
    }
}

// MARK: - Text Overlay View (P2)

/// Text overlay editor for adding text to photos before sending
struct TextOverlayEditor: View {
    @Binding var overlayText: String
    @Binding var textPosition: CGPoint
    @Binding var isEditing: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Tap background to dismiss
            if isEditing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isFocused = false
                        isEditing = false
                    }
                
                VStack(spacing: 16) {
                    TextField(String(localized: "metin ekle..."), text: $overlayText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .padding(.horizontal, 32)
                    
                    HStack(spacing: 16) {
                        Button {
                            overlayText = ""
                            isEditing = false
                        } label: {
                            Text(String(localized: "sil"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            isFocused = false
                            isEditing = false
                        } label: {
                            Text(String(localized: "tamam"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .onAppear { isFocused = true }
            }
            
            // Draggable text overlay on photo
            if !overlayText.isEmpty && !isEditing {
                Text(overlayText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .position(textPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                textPosition = value.location
                            }
                    )
                    .onTapGesture {
                        isEditing = true
                    }
            }
        }
    }
}

// MARK: - Calendar Heatmap View (P2)

/// GitHub-style contribution heatmap for photo history
struct CalendarHeatmapView: View {
    let photos: [PhotoMetadata]
    let onSelectDate: (Date) -> Void
    
    private var photoCountsByDay: [String: Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var counts: [String: Int] = [:]
        for photo in photos {
            let key = formatter.string(from: photo.timestamp)
            counts[key, default: 0] += 1
        }
        return counts
    }
    
    private var last90Days: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<90).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "aktivite"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
            
            let columns = Array(repeating: GridItem(.fixed(12), spacing: 3), count: 7)
            
            LazyHGrid(rows: columns, spacing: 3) {
                let formatter = DateFormatter()
                let _ = formatter.dateFormat = "yyyy-MM-dd"
                
                ForEach(last90Days, id: \.self) { date in
                    let key = formatter.string(from: date)
                    let count = photoCountsByDay[key] ?? 0
                    let opacity = count == 0 ? 0.06 : min(0.15 + Double(count) * 0.2, 0.9)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(opacity))
                        .frame(width: 12, height: 12)
                        .onTapGesture {
                            onSelectDate(date)
                            HapticsManager.playSelection()
                        }
                }
            }
            .frame(height: 120)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - On This Day Memory Card (P2)

struct OnThisDayCard: View {
    let oldPhoto: PhotoMetadata
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                if let thumbUrl = oldPhoto.smallThumbnailUrl ?? oldPhoto.thumbnailUrl,
                   let url = URL(string: thumbUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 48, height: 48)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Label(String(localized: "bugün geçen yıl"), systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(oldPhoto.cityName ?? String(localized: "bir anın var"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - Streak Fire Pulse (P3)

/// Animated flame icon for active streaks in friend cards
struct StreakFireIcon: View {
    let streakCount: Int
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
                .scaleEffect(isPulsing && !reduceMotion ? 1.15 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            
            Text("\(streakCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Read Receipt Marks (P3)

/// Double-check mark indicator for read messages
struct ReadReceiptView: View {
    let isRead: Bool
    
    var body: some View {
        HStack(spacing: -4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(isRead ? .white.opacity(0.8) : .white.opacity(0.25))
        .animation(.easeInOut(duration: 0.3), value: isRead)
    }
}

// MARK: - Link Preview (P3)

/// Simple URL link preview in DM messages
struct LinkPreviewBubble: View {
    let urlString: String
    @State private var title: String?
    @State private var isLoading = true
    
    var body: some View {
        if let url = extractURL(from: urlString) {
            VStack(alignment: .leading, spacing: 6) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white.opacity(0.3)).scaleEffect(0.7)
                        Text(url.host ?? urlString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    if let title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    Text(url.host ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                UIApplication.shared.open(url)
            }
            .task {
                await fetchMetadata(for: url)
            }
        }
    }
    
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, range: range), let url = match.url {
            return url
        }
        return nil
    }
    
    private func fetchMetadata(for url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let html = String(data: data, encoding: .utf8) {
                // Simple title extraction
                if let titleRange = html.range(of: "<title>"),
                   let endRange = html.range(of: "</title>") {
                    title = String(html[titleRange.upperBound..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            #if DEBUG
            print("DEBUG: URL metadata fetch error: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
    }
}

// MARK: - Permission Onboarding (P2)

struct PermissionOnboardingView: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 72, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            VStack(spacing: 14) {
                Button(action: onAllow) {
                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: onSkip) {
                    Text(String(localized: "şimdilik atla"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
