import Foundation

/// Achievement badge definitions for anlık.
public struct Achievement: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let emoji: String
    public let category: Category
    public let requirement: Int  // threshold to unlock
    
    public enum Category: String, Codable, Sendable, CaseIterable {
        case photos = "fotoğraf"
        case streaks = "seri"
        case social = "sosyal"
        case explorer = "kaşif"
    }
    
    // All available achievements
    public static let all: [Achievement] = [
        // Photo milestones
        Achievement(id: "first_photo", title: String(localized: "ilk an"), description: String(localized: "ilk fotoğrafını gönder"), emoji: "camera.fill", category: .photos, requirement: 1),
        Achievement(id: "photos_10", title: String(localized: "anları biriktiren"), description: String(localized: "10 fotoğraf gönder"), emoji: "film", category: .photos, requirement: 10),
        Achievement(id: "photos_50", title: String(localized: "fotoğraf tutkunu"), description: String(localized: "50 fotoğraf gönder"), emoji: "star.fill", category: .photos, requirement: 50),
        Achievement(id: "photos_100", title: String(localized: "yüz an"), description: String(localized: "100 fotoğraf gönder"), emoji: "diamond.fill", category: .photos, requirement: 100),
        Achievement(id: "photos_500", title: String(localized: "efsane"), description: String(localized: "500 fotoğraf gönder"), emoji: "crown.fill", category: .photos, requirement: 500),

        // Streak milestones
        Achievement(id: "streak_7", title: String(localized: "bir hafta"), description: String(localized: "7 günlük bağ yakala"), emoji: "flame.fill", category: .streaks, requirement: 7),
        Achievement(id: "streak_30", title: String(localized: "bir ay"), description: String(localized: "30 günlük bağ yakala"), emoji: "bolt.fill", category: .streaks, requirement: 30),
        Achievement(id: "streak_100", title: String(localized: "yüz gün"), description: String(localized: "100 günlük bağ yakala"), emoji: "trophy.fill", category: .streaks, requirement: 100),
        Achievement(id: "streak_365", title: String(localized: "bir yıl"), description: String(localized: "365 günlük bağ yakala"), emoji: "sparkles", category: .streaks, requirement: 365),

        // Social milestones
        Achievement(id: "first_friend", title: String(localized: "ilk bağlantı"), description: String(localized: "ilk arkadaşını ekle"), emoji: "person.2.fill", category: .social, requirement: 1),
        Achievement(id: "friends_5", title: String(localized: "beşli"), description: String(localized: "5 arkadaş edin"), emoji: "person.3.fill", category: .social, requirement: 5),
        Achievement(id: "friends_10", title: String(localized: "popüler"), description: String(localized: "10 arkadaş edin"), emoji: "globe", category: .social, requirement: 10),
        Achievement(id: "friends_25", title: String(localized: "sosyal kelebek"), description: String(localized: "25 arkadaş edin"), emoji: "leaf.fill", category: .social, requirement: 25),
        Achievement(id: "first_comment", title: String(localized: "ilk yorum"), description: String(localized: "ilk yorumunu yaz"), emoji: "bubble.left.fill", category: .social, requirement: 1),
        Achievement(id: "reaction_50", title: String(localized: "tepki makinesi"), description: String(localized: "50 reaksiyon ver"), emoji: "theatermasks.fill", category: .social, requirement: 50),
        Achievement(id: "dm_100", title: String(localized: "sohbet ustası"), description: String(localized: "100 DM gönder"), emoji: "envelope.fill", category: .social, requirement: 100),

        // Explorer milestones
        Achievement(id: "cities_3", title: String(localized: "gezgin"), description: String(localized: "3 farklı şehirden fotoğraf gönder"), emoji: "map.fill", category: .explorer, requirement: 3),
        Achievement(id: "cities_10", title: String(localized: "kaşif"), description: String(localized: "10 farklı şehirden fotoğraf gönder"), emoji: "safari.fill", category: .explorer, requirement: 10),
        Achievement(id: "daily_prompt_7", title: String(localized: "görev canavarı"), description: String(localized: "7 günlük görev tamamla"), emoji: "checkmark.seal.fill", category: .explorer, requirement: 7),
        Achievement(id: "daily_prompt_30", title: String(localized: "görev ustası"), description: String(localized: "30 günlük görev tamamla"), emoji: "target", category: .explorer, requirement: 30),
        Achievement(id: "night_owl", title: String(localized: "gece kuşu"), description: String(localized: "gece yarısından sonra fotoğraf gönder"), emoji: "moon.fill", category: .explorer, requirement: 1),
        Achievement(id: "early_bird", title: String(localized: "erken kuş"), description: String(localized: "sabah 7'den önce fotoğraf gönder"), emoji: "sunrise.fill", category: .explorer, requirement: 1),
        Achievement(id: "memory_lane", title: String(localized: "anı yolu"), description: String(localized: "'Bugün Geçen Yıl' anısını görüntüle"), emoji: "clock.fill", category: .explorer, requirement: 1),
    ]
}

/// User's unlocked achievements
public struct UserAchievement: Codable, Sendable {
    public let achievementId: String
    public let unlockedAt: Date
}
