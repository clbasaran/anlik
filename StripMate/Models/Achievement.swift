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
        Achievement(id: "first_photo", title: "ilk an", description: "ilk fotoğrafını gönder", emoji: "📸", category: .photos, requirement: 1),
        Achievement(id: "photos_10", title: "anları biriktiren", description: "10 fotoğraf gönder", emoji: "🎞️", category: .photos, requirement: 10),
        Achievement(id: "photos_50", title: "fotoğraf tutkunu", description: "50 fotoğraf gönder", emoji: "🌟", category: .photos, requirement: 50),
        Achievement(id: "photos_100", title: "yüz an", description: "100 fotoğraf gönder", emoji: "💎", category: .photos, requirement: 100),
        Achievement(id: "photos_500", title: "efsane", description: "500 fotoğraf gönder", emoji: "👑", category: .photos, requirement: 500),
        
        // Streak milestones
        Achievement(id: "streak_7", title: "bir hafta", description: "7 günlük seri yakala", emoji: "🔥", category: .streaks, requirement: 7),
        Achievement(id: "streak_30", title: "bir ay", description: "30 günlük seri yakala", emoji: "⚡", category: .streaks, requirement: 30),
        Achievement(id: "streak_100", title: "yüz gün", description: "100 günlük seri yakala", emoji: "🏆", category: .streaks, requirement: 100),
        Achievement(id: "streak_365", title: "bir yıl", description: "365 günlük seri yakala", emoji: "💫", category: .streaks, requirement: 365),
        
        // Social milestones
        Achievement(id: "first_friend", title: "ilk bağlantı", description: "ilk arkadaşını ekle", emoji: "🤝", category: .social, requirement: 1),
        Achievement(id: "friends_5", title: "beşli", description: "5 arkadaş edin", emoji: "👥", category: .social, requirement: 5),
        Achievement(id: "friends_10", title: "popüler", description: "10 arkadaş edin", emoji: "🌐", category: .social, requirement: 10),
        Achievement(id: "friends_25", title: "sosyal kelebek", description: "25 arkadaş edin", emoji: "🦋", category: .social, requirement: 25),
        Achievement(id: "first_comment", title: "ilk yorum", description: "ilk yorumunu yaz", emoji: "💬", category: .social, requirement: 1),
        Achievement(id: "reaction_50", title: "tepki makinesi", description: "50 reaksiyon ver", emoji: "🎭", category: .social, requirement: 50),
        Achievement(id: "dm_100", title: "sohbet ustası", description: "100 DM gönder", emoji: "✉️", category: .social, requirement: 100),
        
        // Explorer milestones
        Achievement(id: "cities_3", title: "gezgin", description: "3 farklı şehirden fotoğraf gönder", emoji: "🗺️", category: .explorer, requirement: 3),
        Achievement(id: "cities_10", title: "kaşif", description: "10 farklı şehirden fotoğraf gönder", emoji: "🧭", category: .explorer, requirement: 10),
        Achievement(id: "daily_prompt_7", title: "görev canavarı", description: "7 günlük görev tamamla", emoji: "✅", category: .explorer, requirement: 7),
        Achievement(id: "daily_prompt_30", title: "görev ustası", description: "30 günlük görev tamamla", emoji: "🎯", category: .explorer, requirement: 30),
        Achievement(id: "night_owl", title: "gece kuşu", description: "gece yarısından sonra fotoğraf gönder", emoji: "🦉", category: .explorer, requirement: 1),
        Achievement(id: "early_bird", title: "erken kuş", description: "sabah 7'den önce fotoğraf gönder", emoji: "🐦", category: .explorer, requirement: 1),
        Achievement(id: "memory_lane", title: "anı yolu", description: "'Bugün Geçen Yıl' anısını görüntüle", emoji: "🕰️", category: .explorer, requirement: 1),
    ]
}

/// User's unlocked achievements
public struct UserAchievement: Codable, Sendable {
    public let achievementId: String
    public let unlockedAt: Date
}
