import AVFoundation
import AudioToolbox

public enum SoundEffect: String {
    case paperplaneWhoosh = "paperplane_whoosh"
}

public class SoundManager {
    public static let shared = SoundManager()
    
    private init() {}
    
    public func playSound(effect: SoundEffect) {
        // Respect user's sound setting
        let soundEnabled = UserDefaults.standard.object(forKey: "sound_enabled") as? Bool ?? true
        guard soundEnabled else { return }
        
        switch effect {
        case .paperplaneWhoosh:
            // Standard notification send sound
            AudioServicesPlaySystemSound(1001)
        }
    }
}
