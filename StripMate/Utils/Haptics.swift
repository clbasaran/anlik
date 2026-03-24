import UIKit

@MainActor
public enum HapticsManager {
    private static var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
    }
    
    public static func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = impactGenerators[style] ?? {
            let g = UIImpactFeedbackGenerator(style: style)
            impactGenerators[style] = g
            return g
        }()
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
    
    public static func playSelection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
