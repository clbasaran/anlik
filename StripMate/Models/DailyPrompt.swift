import Foundation

/// Represents a daily photo challenge/prompt shown to users.
/// Stored in Firestore at: `daily_prompts/{dateString}` (e.g. "2026-03-03")
public struct DailyPrompt: Identifiable, Codable, Sendable {
    /// Date string in "yyyy-MM-dd" format
    public let id: String
    /// The challenge text shown to the user
    public let promptText: String
    /// Localization key for the prompt (if localized prompts are needed later)
    public let promptKey: String
    /// Emoji icon for visual flair
    public let emoji: String
    /// Category for grouping/theming
    public let category: PromptCategory
    /// Timestamp when this prompt becomes active
    public let activeDate: Date

    public enum PromptCategory: String, Codable, Sendable, CaseIterable {
        case selfie = "selfie"
        case mood = "mood"
        case place = "place"
        case food = "food"
        case creative = "creative"
        case social = "social"
        case nature = "nature"
        case random = "random"

        public var displayName: String {
            switch self {
            case .selfie: return String(localized: "Selfie")
            case .mood: return String(localized: "Ruh Hali")
            case .place: return String(localized: "Mekan")
            case .food: return String(localized: "Yemek")
            case .creative: return String(localized: "Yaratıcı")
            case .social: return String(localized: "Sosyal")
            case .nature: return String(localized: "Doğa")
            case .random: return String(localized: "Rastgele")
            }
        }

        public var icon: String {
            switch self {
            case .selfie: return "person.fill"
            case .mood: return "face.smiling"
            case .place: return "mappin.and.ellipse"
            case .food: return "fork.knife"
            case .creative: return "paintbrush.fill"
            case .social: return "person.2.fill"
            case .nature: return "leaf.fill"
            case .random: return "dice.fill"
            }
        }
    }
}

// MARK: - Built-in Prompt Library

public extension DailyPrompt {
    /// A curated list of 60 prompts that rotate. Cloud Function picks one per day.
    static let promptLibrary: [(text: String, emoji: String, category: PromptCategory)] = [
        // Selfie
        ("Şu anki ruh halini bir selfie ile göster", "🤳", .selfie),
        ("En güzel gülüşünle bir selfie çek", "😁", .selfie),
        ("Filtresiz selfie — gerçek sen!", "🪞", .selfie),
        ("Sevdiğin bir şeyle selfie çek", "❤️", .selfie),
        
        // Ruh Hali
        ("Sabahın nasıl görünüyor?", "🌅", .mood),
        ("Şu an nasıl hissediyorsun, göster", "💭", .mood),
        ("Şu anki enerjin tek fotoğrafta", "✨", .mood),
        ("Bugün seni mutlu eden bir şey", "😊", .mood),
        
        // Mekan
        ("Şu an neredesin?", "📍", .place),
        ("Evdeki en sevdiğin köşe", "🏠", .place),
        ("Pencerendeki manzara", "🪟", .place),
        ("Çalışma alanını göster", "💻", .place),
        
        // Yemek
        ("Ne yiyorsun / ne içiyorsun?", "🍽️", .food),
        ("Günün kahvesi veya çayı", "☕", .food),
        ("Günün atıştırmalığı", "🍿", .food),
        ("Bir şey pişir ve göster!", "👨‍🍳", .food),
        
        // Yaratıcı
        ("Yakınında güzel bir şey bul", "🎨", .creative),
        ("Etrafındaki en renkli şey", "🌈", .creative),
        ("Baş aşağı bir fotoğraf çek", "🙃", .creative),
        ("Gölge veya yansıma çekimi", "🌗", .creative),
        ("Herhangi bir şeyin aşırı yakın çekimi", "🔍", .creative),
        ("Yüze benzeyen bir şey bul", "👀", .creative),
        
        // Sosyal
        ("En yakın arkadaşınla fotoğraf", "👯", .social),
        ("Şu an yanında olan biri", "🫂", .social),
        ("Grup fotoğrafı zamanı!", "📸", .social),
        ("Evcil hayvanın (veya gördüğün bir hayvan)", "🐾", .social),
        
        // Doğa
        ("Şu anki gökyüzü", "🌤️", .nature),
        ("Yeşil bir şey", "🌿", .nature),
        ("Dışarıdaki hava durumu", "🌡️", .nature),
        ("Bir çiçek, ağaç veya bitki", "🌸", .nature),
        
        // Rastgele / Eğlenceli
        ("Şu an ayağındaki ayakkabılar", "👟", .random),
        ("Son satın aldığın şey", "🛍️", .random),
        ("Ekranında ne var?", "📱", .random),
        ("Mavi bir şey", "💙", .random),
        ("Bugünkü kıyafetin", "👗", .random),
        ("Yanındaki rastgele bir obje", "🎲", .random),
        ("Gurur duyduğun bir şey", "🏆", .random),
        ("Sahip olduğun en eski şey", "🕰️", .random),
        ("Çantanda / cebinde ne var?", "👜", .random),
        ("Yapılacaklar listen veya planın", "📝", .random),
        
        // Daha fazla çeşitlilik
        ("Ayna selfie'si çek", "🪞", .selfie),
        ("Sabah rutinini göster", "⏰", .mood),
        ("Dışarıda gördüğün ilk şey", "🚪", .place),
        ("En sevdiğin kupa veya bardak", "🍵", .food),
        ("Simetri meydan okuması!", "⚖️", .creative),
        ("Bir yabancının güzel davranışı (yüz yok)", "💛", .social),
        ("Gün batımı veya gün doğumu", "🌇", .nature),
        ("Kırmızı bir şey", "❤️", .random),
        ("Şu an okuduğun veya izlediğin şey", "📖", .random),
        ("Bir şey yapan eller", "🤲", .creative),
        ("Gününü güzelleştiren ne?", "🌟", .mood),
        ("En sevdiğin köşe", "🛋️", .place),
        ("Doku yakın çekimi", "🧱", .creative),
        ("Çocukluk anısı olan bir eşya", "🧸", .random),
        ("Gece gökyüzün", "🌙", .nature),
        ("Minik bir şey", "🐜", .creative),
        ("Siyah-beyaz çekime layık bir kare", "🖤", .creative),
        ("Ayakların + zemin", "👣", .random),
        ("Şu an dinlediğin müzik", "🎵", .random),
        ("Bir kapı veya pencere", "🚪", .creative),
    ]
}
