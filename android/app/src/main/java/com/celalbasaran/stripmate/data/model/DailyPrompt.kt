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
            PromptEntry("bugün nasıl görünüyorsun? hadi bir selfie!", "\uD83E\uDD33", PromptCategory.SELFIE),
            PromptEntry("en doğal halini görmek istiyoruz, filtre yok!", "\uD83E\uDE9E", PromptCategory.SELFIE),
            PromptEntry("bugünkü enerjini yüzünden okuyalım", "\uD83D\uDE01", PromptCategory.SELFIE),
            PromptEntry("en sevdiğin eşyanla bir selfie çeker misin?", "\u2764\uFE0F", PromptCategory.SELFIE),

            // Mood
            PromptEntry("günaydın! sabahın ilk anı nasıl görünüyor?", "\uD83C\uDF05", PromptCategory.MOOD),
            PromptEntry("bugün kendini nasıl hissediyorsun? tek kareyle anlat", "\uD83D\uDCAD", PromptCategory.MOOD),
            PromptEntry("bugün seni gülümseten küçük şey ne oldu?", "\uD83D\uDE0A", PromptCategory.MOOD),
            PromptEntry("şu anki modunu en iyi anlatan kare hangisi?", "\u2728", PromptCategory.MOOD),

            // Place
            PromptEntry("şu an tam olarak neredesin, göster bakalım", "\uD83D\uDCCD", PromptCategory.PLACE),
            PromptEntry("evdeki en rahat köşeni merak ediyoruz", "\uD83C\uDFE0", PromptCategory.PLACE),
            PromptEntry("pencerenden ne görünüyor şu an?", "\uD83E\uDE9F", PromptCategory.PLACE),
            PromptEntry("bugün en çok vakit geçirdiğin yer neresi?", "\uD83D\uDCBB", PromptCategory.PLACE),

            // Food
            PromptEntry("bugün ne yiyorsun, bize de göster!", "\uD83C\uDF7D\uFE0F", PromptCategory.FOOD),
            PromptEntry("kahven mi çayın mı? hadi görelim", "\u2615", PromptCategory.FOOD),
            PromptEntry("bugünkü atıştırmalığın ne, merak ettik", "\uD83C\uDF7F", PromptCategory.FOOD),
            PromptEntry("mutfakta bir şeyler mi pişiriyorsun? göster!", "\uD83D\uDC68\u200D\uD83C\uDF73", PromptCategory.FOOD),

            // Creative
            PromptEntry("etrafına bak, sence en güzel detay hangisi?", "\uD83C\uDFA8", PromptCategory.CREATIVE),
            PromptEntry("en renkli şeyi bul ve çek, renk avı!", "\uD83C\uDF08", PromptCategory.CREATIVE),
            PromptEntry("telefonu ters çevir, baş aşağı bir kare çek!", "\uD83D\uDE43", PromptCategory.CREATIVE),
            PromptEntry("bir gölge ya da yansıma yakala", "\uD83C\uDF17", PromptCategory.CREATIVE),
            PromptEntry("bir şeyin çok yakınından çek, ne olduğunu biz tahmin edelim", "\uD83D\uDD0D", PromptCategory.CREATIVE),
            PromptEntry("etrafında yüze benzeyen bir şey var mı?", "\uD83D\uDC40", PromptCategory.CREATIVE),

            // Social
            PromptEntry("yanındaki en sevdiğin insanla bir kare!", "\uD83D\uDC6F", PromptCategory.SOCIAL),
            PromptEntry("şu an kiminle birliktesin? göster!", "\uD83E\uDEC2", PromptCategory.SOCIAL),
            PromptEntry("bugün gördüğün en tatlı canlı kim?", "\uD83D\uDC3E", PromptCategory.SOCIAL),
            PromptEntry("birlikte olduğun arkadaşlarınla grup fotoğrafı!", "\uD83D\uDCF8", PromptCategory.SOCIAL),

            // Nature
            PromptEntry("başını kaldır, gökyüzü nasıl görünüyor?", "\uD83C\uDF24\uFE0F", PromptCategory.NATURE),
            PromptEntry("etrafında yeşil bir şey bul ve çek", "\uD83C\uDF3F", PromptCategory.NATURE),
            PromptEntry("bugün hava nasıl? bir kareyle anlat", "\uD83C\uDF21\uFE0F", PromptCategory.NATURE),
            PromptEntry("yakınındaki bir çiçek veya bitki var mı?", "\uD83C\uDF38", PromptCategory.NATURE),

            // Random
            PromptEntry("ayağındakilere bak, bugün ne giydin?", "\uD83D\uDC5F", PromptCategory.RANDOM),
            PromptEntry("son aldığın şey neydi? göster bakalım", "\uD83D\uDECD\uFE0F", PromptCategory.RANDOM),
            PromptEntry("telefonunun ekranında şu an ne var?", "\uD83D\uDCF1", PromptCategory.RANDOM),
            PromptEntry("etrafında mavi bir şey bul!", "\uD83D\uDC99", PromptCategory.RANDOM),
            PromptEntry("bugünkü kombinin nasıl?", "\uD83D\uDC57", PromptCategory.RANDOM),
            PromptEntry("yanındaki en rastgele objeyi çek", "\uD83C\uDFB2", PromptCategory.RANDOM),
            PromptEntry("gurur duyduğun bir şeyi göster bize", "\uD83C\uDFC6", PromptCategory.RANDOM),
            PromptEntry("sahip olduğun en eski eşya hangisi?", "\uD83D\uDD70\uFE0F", PromptCategory.RANDOM),
            PromptEntry("cebinde veya çantanda ne var?", "\uD83D\uDC5C", PromptCategory.RANDOM),
            PromptEntry("bugünkü planların neler, göster!", "\uD83D\uDCDD", PromptCategory.RANDOM),

            // Extra variety
            PromptEntry("ayna karşısında bir selfie zamanı!", "\uD83E\uDE9E", PromptCategory.SELFIE),
            PromptEntry("sabah kalktığında ilk gördüğün şey ne?", "\u23F0", PromptCategory.MOOD),
            PromptEntry("kapından dışarı çıkınca ilk ne görüyorsun?", "\uD83D\uDEAA", PromptCategory.PLACE),
            PromptEntry("en sevdiğin bardak veya kupayı göster", "\uD83C\uDF75", PromptCategory.FOOD),
            PromptEntry("simetrik bir kare yakalayabilir misin?", "\u2696\uFE0F", PromptCategory.CREATIVE),
            PromptEntry("bugün gördüğün en güzel davranış neydi?", "\uD83D\uDC9B", PromptCategory.SOCIAL),
            PromptEntry("gün batımını veya doğumunu yakaladın mı?", "\uD83C\uDF07", PromptCategory.NATURE),
            PromptEntry("etrafında kırmızı bir şey bul!", "\u2764\uFE0F", PromptCategory.RANDOM),
            PromptEntry("şu an ne okuyorsun veya ne izliyorsun?", "\uD83D\uDCD6", PromptCategory.RANDOM),
            PromptEntry("ellerinle bir şey yapıyorsan göster!", "\uD83E\uDD32", PromptCategory.CREATIVE),
            PromptEntry("bugün gününü güzelleştiren şey ne oldu?", "\uD83C\uDF1F", PromptCategory.MOOD),
            PromptEntry("en çok sevdiğin köşeyi göster", "\uD83D\uDECB\uFE0F", PromptCategory.PLACE),
            PromptEntry("bir dokunun yakın çekimini yap", "\uD83E\uDDF1", PromptCategory.CREATIVE),
            PromptEntry("çocukluğundan kalan bir eşyan var mı?", "\uD83E\uDDF8", PromptCategory.RANDOM),
            PromptEntry("bu gece gökyüzü nasıl görünüyor?", "\uD83C\uDF19", PromptCategory.NATURE),
            PromptEntry("çok minik bir şey bul ve çek", "\uD83D\uDC1C", PromptCategory.CREATIVE),
            PromptEntry("siyah-beyaz çekilmeyi hak eden bir kare bul", "\uD83D\uDDA4", PromptCategory.CREATIVE),
            PromptEntry("ayaklarına ve zeminine bak, ne görüyorsun?", "\uD83D\uDC63", PromptCategory.RANDOM),
            PromptEntry("şu an kulaklığından ne çalıyor?", "\uD83C\uDFB5", PromptCategory.RANDOM),
            PromptEntry("ilginç bir kapı veya pencere yakala", "\uD83D\uDEAA", PromptCategory.CREATIVE)
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
