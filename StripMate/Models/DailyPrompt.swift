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
        // Selfie — samimi, eğlenceli
        ("bugün nasıl görünüyorsun? hadi bir selfie!", "person.fill", .selfie),
        ("en doğal halini görmek istiyoruz, filtre yok!", "person.crop.square", .selfie),
        ("bugünkü enerjini yüzünden okuyalım", "face.smiling.inverse", .selfie),
        ("en sevdiğin eşyanla bir selfie çeker misin?", "heart.fill", .selfie),

        // Ruh Hali — düşündüren, sıcak
        ("günaydın! sabahın ilk anı nasıl görünüyor?", "sunrise.fill", .mood),
        ("bugün kendini nasıl hissediyorsun? tek kareyle anlat", "thought.bubble", .mood),
        ("bugün seni gülümseten küçük şey ne oldu?", "face.smiling", .mood),
        ("şu anki modunu en iyi anlatan kare hangisi?", "sparkles", .mood),

        // Mekan — keşfe teşvik
        ("şu an tam olarak neredesin, göster bakalım", "mappin", .place),
        ("evdeki en rahat köşeni merak ediyoruz", "house.fill", .place),
        ("pencerenden ne görünüyor şu an?", "window.horizontal", .place),
        ("bugün en çok vakit geçirdiğin yer neresi?", "desktopcomputer", .place),

        // Yemek — sıcak, gündelik
        ("bugün ne yiyorsun, bize de göster!", "fork.knife", .food),
        ("kahven mi çayın mı? hadi görelim", "cup.and.saucer.fill", .food),
        ("bugünkü atıştırmalığın ne, merak ettik", "popcorn.fill", .food),
        ("mutfakta bir şeyler mi pişiriyorsun? göster!", "frying.pan.fill", .food),

        // Yaratıcı — ilham veren
        ("etrafına bak, sence en güzel detay hangisi?", "paintpalette.fill", .creative),
        ("en renkli şeyi bul ve çek, renk avı!", "rainbow", .creative),
        ("telefonu ters çevir, baş aşağı bir kare çek!", "arrow.uturn.down", .creative),
        ("bir gölge ya da yansıma yakala", "circle.lefthalf.filled", .creative),
        ("bir şeyin çok yakınından çek, ne olduğunu biz tahmin edelim", "magnifyingglass", .creative),
        ("etrafında yüze benzeyen bir şey var mı?", "eye.fill", .creative),

        // Sosyal — arkadaşça
        ("yanındaki en sevdiğin insanla bir kare!", "person.2.fill", .social),
        ("şu an kiminle birliktesin? göster!", "figure.2", .social),
        ("bugün gördüğün en tatlı canlı kim?", "pawprint.fill", .social),
        ("birlikte olduğun arkadaşlarınla grup fotoğrafı!", "camera.fill", .social),

        // Doğa — gözlem
        ("başını kaldır, gökyüzü nasıl görünüyor?", "cloud.sun.fill", .nature),
        ("etrafında yeşil bir şey bul ve çek", "leaf.fill", .nature),
        ("bugün hava nasıl? bir kareyle anlat", "thermometer.medium", .nature),
        ("yakınındaki bir çiçek veya bitki var mı?", "camera.macro", .nature),

        // Rastgele — eğlenceli, şaşırtıcı
        ("ayağındakilere bak, bugün ne giydin?", "shoeprint.fill", .random),
        ("son aldığın şey neydi? göster bakalım", "bag.fill", .random),
        ("telefonunun ekranında şu an ne var?", "iphone", .random),
        ("etrafında mavi bir şey bul!", "drop.fill", .random),
        ("bugünkü kombinin nasıl?", "tshirt.fill", .random),
        ("yanındaki en rastgele objeyi çek", "dice.fill", .random),
        ("gurur duyduğun bir şeyi göster bize", "trophy.fill", .random),
        ("sahip olduğun en eski eşya hangisi?", "clock.fill", .random),
        ("cebinde veya çantanda ne var?", "bag.fill", .random),
        ("bugünkü planların neler, göster!", "list.clipboard", .random),

        // Ekstra çeşitlilik
        ("ayna karşısında bir selfie zamanı!", "person.crop.square", .selfie),
        ("sabah kalktığında ilk gördüğün şey ne?", "alarm.fill", .mood),
        ("kapından dışarı çıkınca ilk ne görüyorsun?", "door.left.hand.open", .place),
        ("en sevdiğin bardak veya kupayı göster", "mug.fill", .food),
        ("simetrik bir kare yakalayabilir misin?", "square.split.2x2", .creative),
        ("bugün gördüğün en güzel davranış neydi?", "hand.thumbsup.fill", .social),
        ("gün batımını veya doğumunu yakaladın mı?", "sunset.fill", .nature),
        ("etrafında kırmızı bir şey bul!", "heart.fill", .random),
        ("şu an ne okuyorsun veya ne izliyorsun?", "book.fill", .random),
        ("ellerinle bir şey yapıyorsan göster!", "hand.raised.fill", .creative),
        ("bugün gününü güzelleştiren şey ne oldu?", "star.fill", .mood),
        ("en çok sevdiğin köşeyi göster", "sofa.fill", .place),
        ("bir dokunun yakın çekimini yap", "square.grid.3x3.fill", .creative),
        ("çocukluğundan kalan bir eşyan var mı?", "teddybear.fill", .random),
        ("bu gece gökyüzü nasıl görünüyor?", "moon.fill", .nature),
        ("çok minik bir şey bul ve çek", "ant.fill", .creative),
        ("siyah-beyaz çekilmeyi hak eden bir kare bul", "circle.lefthalf.filled", .creative),
        ("ayaklarına ve zeminine bak, ne görüyorsun?", "figure.walk", .random),
        ("şu an kulaklığından ne çalıyor?", "music.note", .random),
        ("ilginç bir kapı veya pencere yakala", "door.left.hand.open", .creative),
    ]
}
