import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Rozet kilit acma mantigi.
/// Kullanici verilerini kontrol eder ve kosullari saglayan rozetleri Firestore'a kaydeder.
@MainActor @Observable
public final class AchievementService {
    public static let shared = AchievementService()

    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }

    /// Kilit acilmis rozet ID'leri (yerel onbellek)
    public private(set) var unlockedIds: Set<String> = []

    /// Yeni acilan rozet — UI'da toast gostermek icin
    public var newlyUnlockedAchievement: Achievement?

    private var listener: ListenerRegistration?
    private var hasLoaded = false

    private init() {}

    // MARK: - Dinleyici

    /// Firestore'dan acilmis rozetleri dinlemeye basla
    public func startListening() {
        guard let uid = auth.currentUser?.uid else { return }
        stopListening()

        listener = db.collection("users").document(uid).collection("achievements")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.unlockedIds = Set(documents.map { $0.documentID })
                    self.hasLoaded = true
                }
            }
    }

    /// Dinleyiciyi durdur (logout'ta cagir)
    public func stopListening() {
        listener?.remove()
        listener = nil
        unlockedIds.removeAll()
        hasLoaded = false
    }

    // MARK: - Toplu Kontrol

    /// Tum rozetleri kontrol et — login sonrasi ve periyodik olarak cagrilabilir
    public func checkAll() async {
        guard let uid = auth.currentUser?.uid else { return }

        // Ilk yuklenmeyi bekle
        if !hasLoaded {
            try? await Task.sleep(for: .seconds(1))
        }

        await checkPhotoAchievements(userId: uid)
        await checkStreakAchievements(userId: uid)
        await checkSocialAchievements(userId: uid)
        await checkExplorerAchievements(userId: uid)
    }

    // MARK: - Foto Rozetleri

    /// Foto gonderimi sonrasi cagir
    public func onPhotoSent() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkPhotoAchievements(userId: uid)
        await checkTimeBasedAchievements(userId: uid)
    }

    private func checkPhotoAchievements(userId: String) async {
        do {
            let count = try await db.collection("strips")
                .whereField("senderId", isEqualTo: userId)
                .count
                .getAggregation(source: .server)
            let photoCount = count.count.intValue

            let photoAchievements: [(id: String, threshold: Int)] = [
                ("first_photo", 1),
                ("photos_10", 10),
                ("photos_50", 50),
                ("photos_100", 100),
                ("photos_500", 500)
            ]

            for achievement in photoAchievements {
                if photoCount >= achievement.threshold {
                    await unlock(achievement.id, for: userId)
                }
            }
        } catch {
            AppLogger.service.error("AchievementService foto kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Seri Rozetleri

    /// Seri guncellendikten sonra cagir
    public func onStreakUpdated() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkStreakAchievements(userId: uid)
    }

    private func checkStreakAchievements(userId: String) async {
        do {
            let snapshot = try await db.collection("streaks")
                .whereField("userIds", arrayContains: userId)
                .limit(to: 50)
                .getDocuments()

            var maxStreak = 0
            for doc in snapshot.documents {
                let current = doc.data()["currentStreak"] as? Int ?? 0
                let longest = doc.data()["longestStreak"] as? Int ?? 0
                maxStreak = max(maxStreak, max(current, longest))
            }

            let streakAchievements: [(id: String, threshold: Int)] = [
                ("streak_7", 7),
                ("streak_30", 30),
                ("streak_100", 100),
                ("streak_365", 365)
            ]

            for achievement in streakAchievements {
                if maxStreak >= achievement.threshold {
                    await unlock(achievement.id, for: userId)
                }
            }
        } catch {
            AppLogger.service.error("AchievementService seri kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Sosyal Rozetler

    /// Arkadas eklendikten sonra cagir
    public func onFriendAdded() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkSocialAchievements(userId: uid)
    }

    /// Yorum yapildiktan sonra cagir
    public func onCommentSent() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkCommentAchievement(userId: uid)
    }

    /// Reaksiyon verildikten sonra cagir
    public func onReactionSent() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkReactionAchievement(userId: uid)
    }

    /// DM gonderildikten sonra cagir
    public func onDirectMessageSent() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkDMAchievement(userId: uid)
    }

    private func checkSocialAchievements(userId: String) async {
        do {
            // Arkadas sayisi
            let friendSnapshot = try await db.collection("users").document(userId)
                .collection("friendships")
                .whereField("isPending", isEqualTo: false)
                .count
                .getAggregation(source: .server)
            let friendCount = friendSnapshot.count.intValue

            let friendAchievements: [(id: String, threshold: Int)] = [
                ("first_friend", 1),
                ("friends_5", 5),
                ("friends_10", 10),
                ("friends_25", 25)
            ]

            for achievement in friendAchievements {
                if friendCount >= achievement.threshold {
                    await unlock(achievement.id, for: userId)
                }
            }
        } catch {
            AppLogger.service.error("AchievementService sosyal kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }

        await checkCommentAchievement(userId: userId)
        await checkReactionAchievement(userId: userId)
        await checkDMAchievement(userId: userId)
    }

    private func checkCommentAchievement(userId: String) async {
        guard !unlockedIds.contains("first_comment") else { return }
        do {
            // Strip chat mesajlari "messages" subcollection'da (strips/{id}/chats/{receiverId}/messages)
            let snapshot = try await db.collectionGroup("messages")
                .whereField("senderId", isEqualTo: userId)
                .limit(to: 1)
                .getDocuments()
            if !snapshot.documents.isEmpty {
                await unlock("first_comment", for: userId)
            }
        } catch {
            AppLogger.service.error("AchievementService yorum kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkReactionAchievement(userId: String) async {
        guard !unlockedIds.contains("reaction_50") else { return }
        // Count reactions by counting DM messages and strip chat messages with reactions containing this user
        // Increment totalReactions on user doc whenever a reaction is toggled (done in ChatViewModel/DMViewModel)
        // Fallback: count from messages collection group
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            var reactionCount = userDoc.data()?["totalReactions"] as? Int ?? 0

            // If counter not set yet, count from DM messages with reactions
            if reactionCount == 0 {
                let dmSnapshot = try await db.collectionGroup("messages")
                    .whereField("reactions.\(userId)", isGreaterThan: "")
                    .limit(to: 50)
                    .getDocuments()
                reactionCount = dmSnapshot.documents.count
                // Persist the count for future checks
                if reactionCount > 0 {
                    try? await db.collection("users").document(userId).updateData(["totalReactions": reactionCount])
                }
            }

            if reactionCount >= 50 {
                await unlock("reaction_50", for: userId)
            }
        } catch {
            AppLogger.service.error("AchievementService reaksiyon kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkDMAchievement(userId: String) async {
        guard !unlockedIds.contains("dm_100") else { return }
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            var dmCount = userDoc.data()?["totalDMs"] as? Int ?? 0

            // If counter not set, count from DM messages sent by this user
            if dmCount == 0 {
                let dmSnapshot = try await db.collectionGroup("messages")
                    .whereField("senderId", isEqualTo: userId)
                    .whereField("receiverId", isGreaterThan: "")
                    .limit(to: 100)
                    .getDocuments()
                dmCount = dmSnapshot.documents.count
                if dmCount > 0 {
                    try? await db.collection("users").document(userId).updateData(["totalDMs": dmCount])
                }
            }

            if dmCount >= 100 {
                await unlock("dm_100", for: userId)
            }
        } catch {
            AppLogger.service.error("AchievementService DM kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Kasif Rozetleri

    /// Farkli sehir kontrolu icin foto gonderimi sonrasi cagir
    public func onPhotoSentFromCity(_ cityName: String?) async {
        guard let uid = auth.currentUser?.uid, let city = cityName, !city.isEmpty else { return }
        await checkCityAchievements(userId: uid)
    }

    /// Gunluk gorev tamamlandiginda cagir
    public func onDailyPromptCompleted() async {
        guard let uid = auth.currentUser?.uid else { return }
        await checkDailyPromptAchievements(userId: uid)
    }

    /// "Bugun Gecen Yil" ani goruntulediginde cagir
    public func onMemoryLaneViewed() async {
        guard let uid = auth.currentUser?.uid else { return }
        await unlock("memory_lane", for: uid)
    }

    private func checkExplorerAchievements(userId: String) async {
        await checkCityAchievements(userId: userId)
        await checkDailyPromptAchievements(userId: userId)
        await checkTimeBasedAchievements(userId: userId)
    }

    private func checkCityAchievements(userId: String) async {
        // First check if the highest city achievement is already unlocked
        let maxThreshold = 10
        if unlockedIds.contains("cities_10") { return }

        do {
            // Use a limited query — fetch only strips with city data, capped at a reasonable limit.
            // We only need 10 unique cities for the highest achievement, so 200 strips is plenty.
            let snapshot = try await db.collection("strips")
                .whereField("senderId", isEqualTo: userId)
                .whereField("cityName", isNotEqualTo: "")
                .limit(to: 200)
                .getDocuments()

            var cities = Set<String>()
            for doc in snapshot.documents {
                if let city = doc.data()["cityName"] as? String, !city.isEmpty {
                    cities.insert(city)
                }
                // Early exit if we already have enough unique cities
                if cities.count >= maxThreshold { break }
            }

            let cityAchievements: [(id: String, threshold: Int)] = [
                ("cities_3", 3),
                ("cities_10", 10)
            ]

            for achievement in cityAchievements {
                if cities.count >= achievement.threshold {
                    await unlock(achievement.id, for: userId)
                }
            }
        } catch {
            AppLogger.service.error("AchievementService sehir kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkDailyPromptAchievements(userId: String) async {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let completedCount = userDoc.data()?["dailyPromptCompletedCount"] as? Int ?? 0

            let promptAchievements: [(id: String, threshold: Int)] = [
                ("daily_prompt_7", 7),
                ("daily_prompt_30", 30)
            ]

            for achievement in promptAchievements {
                if completedCount >= achievement.threshold {
                    await unlock(achievement.id, for: userId)
                }
            }
        } catch {
            AppLogger.service.error("AchievementService gunluk gorev kontrol hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Saat bazli rozetler: gece kusu (00:00-05:00) ve erken kus (05:00-07:00)
    private func checkTimeBasedAchievements(userId: String) async {
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 0 && hour < 5 {
            await unlock("night_owl", for: userId)
        }

        if hour >= 5 && hour < 7 {
            await unlock("early_bird", for: userId)
        }
    }

    // MARK: - Kilit Acma

    /// Rozeti ac ve Firestore'a kaydet
    private func unlock(_ achievementId: String, for userId: String) async {
        // Zaten acilmissa atla
        guard !unlockedIds.contains(achievementId) else { return }

        do {
            try await db.collection("users").document(userId).collection("achievements").document(achievementId).setData([
                "achievementId": achievementId,
                "unlockedAt": FieldValue.serverTimestamp()
            ])

            // Yerel onbellegi guncelle
            unlockedIds.insert(achievementId)

            // Yeni rozet bildirimini ayarla
            if let achievement = Achievement.all.first(where: { $0.id == achievementId }) {
                newlyUnlockedAchievement = achievement
                AppLogger.service.info("Rozet acildi: \(achievement.title, privacy: .public) [\(achievement.emoji, privacy: .public)]")
            }
        } catch {
            AppLogger.service.error("AchievementService rozet kaydetme hatasi: \(error.localizedDescription, privacy: .public)")
        }
    }
}
