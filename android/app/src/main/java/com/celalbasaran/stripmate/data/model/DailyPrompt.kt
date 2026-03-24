package com.celalbasaran.stripmate.data.model

import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date

data class DailyPrompt(
    val id: String = "",
    val promptText: String = "",
    val emoji: String = "",
    val category: PromptCategory = PromptCategory.RANDOM,
    val activeDate: Date = Date(),
    val isCompletedToday: Boolean = false
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("promptText", promptText)
        put("emoji", emoji)
        put("category", category.value)
        put("activeDate", com.google.firebase.Timestamp(activeDate))
        put("isCompletedToday", isCompletedToday)
    }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): DailyPrompt? {
            if (!doc.exists()) return null
            val categoryStr = doc.getString("category") ?: "random"
            return DailyPrompt(
                id = doc.id,
                promptText = doc.getString("promptText") ?: "",
                emoji = doc.getString("emoji") ?: "",
                category = PromptCategory.fromString(categoryStr),
                activeDate = doc.getTimestamp("activeDate")?.toDate() ?: Date(),
                isCompletedToday = doc.getBoolean("isCompletedToday") ?: false
            )
        }

        val PROMPT_LIBRARY: List<PromptEntry> = listOf(
            // Selfie
            PromptEntry("Şu anki ruh halini bir selfie ile göster", "\uD83E\uDD33", PromptCategory.SELFIE),
            PromptEntry("En güzel gülüşünle bir selfie çek", "\uD83D\uDE01", PromptCategory.SELFIE),
            PromptEntry("Filtresiz selfie — gerçek sen!", "\uD83E\uDE9E", PromptCategory.SELFIE),
            PromptEntry("Sevdiğin bir şeyle selfie çek", "\u2764\uFE0F", PromptCategory.SELFIE),

            // Mood
            PromptEntry("Sabahın nasıl görünüyor?", "\uD83C\uDF05", PromptCategory.MOOD),
            PromptEntry("Şu an nasıl hissediyorsun, göster", "\uD83D\uDCAD", PromptCategory.MOOD),
            PromptEntry("Şu anki enerjin tek fotoğrafta", "\u2728", PromptCategory.MOOD),
            PromptEntry("Bugün seni mutlu eden bir şey", "\uD83D\uDE0A", PromptCategory.MOOD),

            // Place
            PromptEntry("Şu an neredesin?", "\uD83D\uDCCD", PromptCategory.PLACE),
            PromptEntry("Evdeki en sevdiğin köşe", "\uD83C\uDFE0", PromptCategory.PLACE),
            PromptEntry("Pencerendeki manzara", "\uD83E\uDE9F", PromptCategory.PLACE),
            PromptEntry("Çalışma alanını göster", "\uD83D\uDCBB", PromptCategory.PLACE),

            // Food
            PromptEntry("Ne yiyorsun / ne içiyorsun?", "\uD83C\uDF7D\uFE0F", PromptCategory.FOOD),
            PromptEntry("Günün kahvesi veya çayı", "\u2615", PromptCategory.FOOD),
            PromptEntry("Günün atıştırmalığı", "\uD83C\uDF7F", PromptCategory.FOOD),
            PromptEntry("Bir şey pişir ve göster!", "\uD83D\uDC68\u200D\uD83C\uDF73", PromptCategory.FOOD),

            // Creative
            PromptEntry("Yakınında güzel bir şey bul", "\uD83C\uDFA8", PromptCategory.CREATIVE),
            PromptEntry("Etrafındaki en renkli şey", "\uD83C\uDF08", PromptCategory.CREATIVE),
            PromptEntry("Baş aşağı bir fotoğraf çek", "\uD83D\uDE43", PromptCategory.CREATIVE),
            PromptEntry("Gölge veya yansıma çekimi", "\uD83C\uDF17", PromptCategory.CREATIVE),
            PromptEntry("Herhangi bir şeyin aşırı yakın çekimi", "\uD83D\uDD0D", PromptCategory.CREATIVE),
            PromptEntry("Yüze benzeyen bir şey bul", "\uD83D\uDC40", PromptCategory.CREATIVE),

            // Social
            PromptEntry("En yakın arkadaşınla fotoğraf", "\uD83D\uDC6F", PromptCategory.SOCIAL),
            PromptEntry("Şu an yanında olan biri", "\uD83E\uDEC2", PromptCategory.SOCIAL),
            PromptEntry("Grup fotoğrafı zamanı!", "\uD83D\uDCF8", PromptCategory.SOCIAL),
            PromptEntry("Evcil hayvanın (veya gördüğün bir hayvan)", "\uD83D\uDC3E", PromptCategory.SOCIAL),

            // Nature
            PromptEntry("Şu anki gökyüzü", "\uD83C\uDF24\uFE0F", PromptCategory.NATURE),
            PromptEntry("Yeşil bir şey", "\uD83C\uDF3F", PromptCategory.NATURE),
            PromptEntry("Dışarıdaki hava durumu", "\uD83C\uDF21\uFE0F", PromptCategory.NATURE),
            PromptEntry("Bir çiçek, ağaç veya bitki", "\uD83C\uDF38", PromptCategory.NATURE),

            // Random
            PromptEntry("Şu an ayağındaki ayakkabılar", "\uD83D\uDC5F", PromptCategory.RANDOM),
            PromptEntry("Son satın aldığın şey", "\uD83D\uDECD\uFE0F", PromptCategory.RANDOM),
            PromptEntry("Ekranında ne var?", "\uD83D\uDCF1", PromptCategory.RANDOM),
            PromptEntry("Mavi bir şey", "\uD83D\uDC99", PromptCategory.RANDOM),
            PromptEntry("Bugünkü kıyafetin", "\uD83D\uDC57", PromptCategory.RANDOM),
            PromptEntry("Yanındaki rastgele bir obje", "\uD83C\uDFB2", PromptCategory.RANDOM),
            PromptEntry("Gurur duyduğun bir şey", "\uD83C\uDFC6", PromptCategory.RANDOM),
            PromptEntry("Sahip olduğun en eski şey", "\uD83D\uDD70\uFE0F", PromptCategory.RANDOM),
            PromptEntry("Çantanda / cebinde ne var?", "\uD83D\uDC5C", PromptCategory.RANDOM),
            PromptEntry("Yapılacaklar listen veya planın", "\uD83D\uDCDD", PromptCategory.RANDOM),

            // Extra variety
            PromptEntry("Ayna selfie'si çek", "\uD83E\uDE9E", PromptCategory.SELFIE),
            PromptEntry("Sabah rutinini göster", "\u23F0", PromptCategory.MOOD),
            PromptEntry("Dışarıda gördüğün ilk şey", "\uD83D\uDEAA", PromptCategory.PLACE),
            PromptEntry("En sevdiğin kupa veya bardak", "\uD83C\uDF75", PromptCategory.FOOD),
            PromptEntry("Simetri meydan okuması!", "\u2696\uFE0F", PromptCategory.CREATIVE),
            PromptEntry("Bir yabancının güzel davranışı (yüz yok)", "\uD83D\uDC9B", PromptCategory.SOCIAL),
            PromptEntry("Gün batımı veya gün doğumu", "\uD83C\uDF07", PromptCategory.NATURE),
            PromptEntry("Kırmızı bir şey", "\u2764\uFE0F", PromptCategory.RANDOM),
            PromptEntry("Şu an okuduğun veya izlediğin şey", "\uD83D\uDCD6", PromptCategory.RANDOM),
            PromptEntry("Bir şey yapan eller", "\uD83E\uDD32", PromptCategory.CREATIVE),
            PromptEntry("Gününü güzelleştiren ne?", "\uD83C\uDF1F", PromptCategory.MOOD),
            PromptEntry("En sevdiğin köşe", "\uD83D\uDECB\uFE0F", PromptCategory.PLACE),
            PromptEntry("Doku yakın çekimi", "\uD83E\uDDF1", PromptCategory.CREATIVE),
            PromptEntry("Çocukluk anısı olan bir eşya", "\uD83E\uDDF8", PromptCategory.RANDOM),
            PromptEntry("Gece gökyüzün", "\uD83C\uDF19", PromptCategory.NATURE),
            PromptEntry("Minik bir şey", "\uD83D\uDC1C", PromptCategory.CREATIVE),
            PromptEntry("Siyah-beyaz çekime layık bir kare", "\uD83D\uDDA4", PromptCategory.CREATIVE),
            PromptEntry("Ayakların + zemin", "\uD83D\uDC63", PromptCategory.RANDOM),
            PromptEntry("Şu an dinlediğin müzik", "\uD83C\uDFB5", PromptCategory.RANDOM),
            PromptEntry("Bir kapı veya pencere", "\uD83D\uDEAA", PromptCategory.CREATIVE)
        )
    }
}

data class PromptEntry(
    val text: String,
    val emoji: String,
    val category: PromptCategory
)

enum class PromptCategory(val value: String, val displayName: String, val icon: String) {
    SELFIE("selfie", "Selfie", "person"),
    MOOD("mood", "Ruh Hali", "sentiment_satisfied"),
    PLACE("place", "Mekan", "place"),
    FOOD("food", "Yemek", "restaurant"),
    CREATIVE("creative", "Yaratıcı", "brush"),
    SOCIAL("social", "Sosyal", "group"),
    NATURE("nature", "Doğa", "eco"),
    RANDOM("random", "Rastgele", "casino");

    companion object {
        fun fromString(value: String): PromptCategory =
            entries.firstOrNull { it.value == value } ?: RANDOM
    }
}
