# 🗄️ anlık. (StripMate) — Firestore Şema ve Cloud Functions Dokümanı

> **Tarih:** 6 Mart 2026 | **Versiyon:** 2.0.0 | **Firebase Proje:** stripmate

---

## 1. Firestore Collection Şeması

### 1.1 `users/{userId}`

Kullanıcı profil ve ayar bilgileri.

| Alan | Tip | Açıklama | Zorunlu |
|------|-----|----------|---------|
| `displayName` | `string` | Görünen ad | ✅ |
| `username` | `string` | Benzersiz kullanıcı adı (lowercase, uniqueness Cloud Function ile sağlanır) | ✅ |
| `email` | `string` | E-posta adresi | ✅ |
| `avatarUrl` | `string` | Profil fotoğrafı URL'i | ❌ |
| `inviteCode` | `string` | 8 haneli benzersiz davet kodu | ✅ |
| `bio` | `string` | Biyografi (max 60 karakter — server-validated) | ❌ |
| `statusEmoji` | `string` | Durum emojisi (max 4 karakter — server-validated) | ❌ |
| `fcmToken` | `string` | FCM push notification token (legacy path) | ❌ |
| `consent` | `map` | KVKK rıza bilgileri (bir kez set edildikten sonra değiştirilemez) | ✅ |
| `consent.kvkk` | `boolean` | KVKK aydınlatma metni onayı | ✅ |
| `consent.privacy` | `boolean` | Gizlilik politikası onayı | ✅ |
| `consent.terms` | `boolean` | Kullanım şartları onayı | ✅ |
| `consent.timestamp` | `timestamp` | Rıza zamanı | ✅ |
| `notificationPreferences` | `map` | Bildirim tercihleri | ❌ |
| `notificationPreferences.notif_strips` | `boolean` | Fotoğraf bildirimleri | ❌ |
| `notificationPreferences.notif_dms` | `boolean` | DM bildirimleri | ❌ |
| `notificationPreferences.notif_friends` | `boolean` | Arkadaşlık bildirimleri | ❌ |
| `notificationPreferences.quiet_hours_enabled` | `boolean` | Sessiz saatler aktif mi | ❌ |
| `notificationPreferences.quiet_hours_start` | `number` | Sessiz saat başlangıcı (0-23) | ❌ |
| `notificationPreferences.quiet_hours_end` | `number` | Sessiz saat bitişi (0-23) | ❌ |
| `createdAt` | `timestamp` | Hesap oluşturulma tarihi | ✅ |

**Alt Koleksiyonlar:**

#### `users/{userId}/private/{docId}`
Hassas veriler (sadece kullanıcı erişebilir).

| Doküman ID | Alan | Tip | Açıklama |
|------------|------|-----|----------|
| `tokens` | `fcmToken` | `string` | FCM token (güvenli path) |

#### `users/{userId}/friendships/{friendId}`
Arkadaşlık ilişkileri.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `isPending` | `boolean` | İstek bekliyor mu |
| `requesterId` | `string` | İsteği gönderen |
| `timestamp` | `timestamp` | İstek/kabul zamanı (server timestamp zorunlu) |

#### `users/{userId}/blocked/{blockedId}`
Engellenen kullanıcılar. Sadece kullanıcı kendi listesine erişebilir.

---

### 1.2 `strips/{stripId}`

Fotoğraf paylaşımları (anlar).

| Alan | Tip | Açıklama | Zorunlu |
|------|-----|----------|---------|
| `senderId` | `string` | Gönderen kullanıcı ID | ✅ |
| `imageUrl` | `string` | Orijinal fotoğraf URL'i (Firebase Storage) | ✅ |
| `thumbnailUrl` | `string` | 800x800 thumbnail URL (Cloud Function tarafından set edilir) | ❌ |
| `smallThumbnailUrl` | `string` | 200x200 küçük thumbnail URL | ❌ |
| `receiverIds` | `array<string>` | Alıcı kullanıcı ID'leri (sender dahil, min 2 — max 51) | ✅ |
| `timestamp` | `timestamp` | Paylaşım zamanı (server timestamp zorunlu) | ✅ |
| `latitude` | `number` | Enlem koordinatı | ❌ |
| `longitude` | `number` | Boylam koordinatı | ❌ |
| `cityName` | `string` | Şehir adı | ❌ |
| `reactions` | `map` | Emoji tepkileri (`{userId: emoji}`) | ❌ |
| `flagged` | `boolean` | İçerik moderasyonu tarafından işaretlendi | ❌ |
| `flagReason` | `string` | İşaretleme nedeni (ör: `auto_moderation`) | ❌ |

**Güvenlik:**
- Oluşturma: `senderId == auth.uid`, timestamp server zorunlu, receiverIds boyut kontrolü
- Okuma: Sadece `senderId` veya `receiverIds` içindeki kullanıcılar
- Güncelleme: Gönderen tüm alanları, alıcı sadece kendini receiverIds'den çıkarabilir
- Silme: Sadece gönderen veya admin

**Alt Koleksiyonlar:**

#### `strips/{stripId}/comments/{commentId}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `senderId` | `string` | Yorum yapan kullanıcı |
| `text` | `string` | Yorum metni veya emoji |
| `timestamp` | `timestamp` | Server timestamp zorunlu |
| `type` | `string` | `text` veya `emoji` |

---

### 1.3 `streaks/{streakId}`

Streak (seri) verileri. ID formatı: `uid1_uid2` (alfabetik sıralı).

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `string` | Streak ID (uid1_uid2) |
| `userIds` | `array<string>` | İki kullanıcının ID'leri (her zaman 2 eleman) |
| `currentStreak` | `number` | Mevcut seri uzunluğu (gün) |
| `longestStreak` | `number` | En uzun seri |
| `totalExchanges` | `number` | Toplam fotoğraf alışverişi |
| `lastExchangeDate` | `timestamp` | Son paylaşım tarihi |
| `lastSenderId` | `string` | Son gönderen kullanıcı |
| `friendshipScore` | `number` | Arkadaşlık puanı (0-1000) |

**Friendship Score Formülü (Cloud Function):**
```
streakPts    = min(400, log2(currentStreak + 1) × 60)   // %40
exchangePts  = min(400, log2(totalExchanges + 1) × 45)  // %40
recencyPts   = 200 (eğer bugün paylaşıldıysa)           // %20
friendshipScore = min(1000, streakPts + exchangePts + recencyPts)
```

**Friendship Tier Eşleme:**
| Tier | Score Aralığı | Emoji |
|------|--------------|-------|
| New Friend | 0–49 | 🌱 |
| Casual | 50–149 | 😊 |
| Close Friend | 150–349 | ⭐ |
| Best Friend | 350–699 | 💛 |
| Soulmate | 700+ | 💎 |

**Güvenlik:**
- Okuma: Sadece `userIds` içindeki kullanıcılar
- Oluşturma/Güncelleme: Sadece katılımcılar + Cloud Function
- Silme: Sadece Cloud Function (Admin SDK)

---

### 1.4 `direct_messages/{threadId}/messages/{messageId}`

Direkt mesajlaşma. Thread ID formatı: `uid1_uid2` (alfabetik sıralı).

**Thread dokümanı (`direct_messages/{threadId}`):**
| Alan | Tip | Açıklama |
|------|-----|----------|
| Metadata ve typing indicator verileri | | Sadece katılımcılar erişebilir |

**Mesaj dokümanı (`messages/{messageId}`):**
| Alan | Tip | Açıklama |
|------|-----|----------|
| `senderId` | `string` | Gönderen |
| `receiverId` | `string` | Alıcı |
| `text` | `string` | Mesaj metni (max 2000 karakter — server validated) |
| `timestamp` | `timestamp` | Gönderim zamanı |
| `readAt` | `timestamp` | Okunma zamanı |
| `isDeleted` | `boolean` | Silinmiş mi (soft delete) |
| `replyToId` | `string` | Yanıtlanan mesaj ID |
| `replyToText` | `string` | Yanıtlanan mesajın kısa özeti |
| `replyToSenderId` | `string` | Yanıtlanan mesajı gönderen |
| `reactions` | `map` | Emoji tepkileri |

---

### 1.5 `notifications/{notifId}`

Uygulama içi bildirimler.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `userId` | `string` | Bildirimi alan kullanıcı |
| `senderId` | `string` | Bildirimi tetikleyen kullanıcı |
| `type` | `string` | Bildirim tipi |
| `timestamp` | `timestamp` | Server timestamp zorunlu |
| `read` | `boolean` | Okundu mu |

---

### 1.6 `daily_prompts/{dateId}`

Günlük fotoğraf görevleri. `dateId` formatı: `YYYY-MM-DD`.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `promptText` | `string` | Görev metni (Türkçe) |
| `emoji` | `string` | Görev emojisi |
| `category` | `string` | Kategori: selfie, mood, place, food, creative, social, nature, random |
| `activeDate` | `timestamp` | Aktif tarih |

**Alt Koleksiyon:**

#### `daily_prompts/{dateId}/completions/{userId}`
| Alan | Tip | Açıklama |
|------|-----|----------|
| `userId` | `string` | Tamamlayan kullanıcı |
| `completedAt` | `timestamp` | Tamamlanma zamanı |

**Güvenlik:**
- Okuma: Tüm authenticated kullanıcılar
- Yazma: Sadece Cloud Function (Admin SDK)
- Completions: Kullanıcı sadece kendi kaydını oluşturabilir

---

### 1.7 `reports/{reportId}`

Kullanıcı şikâyetleri.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `reporterId` | `string` | Şikâyet eden (auth.uid ile eşleşmeli) |
| `reportedUserId` | `string` | Şikâyet edilen |
| `reason` | `string` | Şikâyet nedeni |
| `timestamp` | `timestamp` | Şikâyet zamanı |

**Güvenlik:**
- Oluşturma: Authenticated kullanıcılar (sadece kendi adına)
- Okuma/Güncelleme/Silme: Sadece admin

---

### 1.8 `usernames/{username}`

Kullanıcı adı benzersizlik kontrolü (Cloud Function tarafından yönetilir).

| Alan | Tip | Açıklama |
|------|-----|----------|
| `userId` | `string` | Bu username'i kullanan kullanıcı |
| `reservedAt` | `timestamp` | Rezerve edilme zamanı |

**Güvenlik:**
- Okuma: Tüm authenticated kullanıcılar (availability check)
- Yazma: Sadece Cloud Function (Admin SDK)

---

## 2. Cloud Functions (11 adet)

### 2.1 Firestore Trigger'ları

| # | Fonksiyon | Trigger | Açıklama |
|---|-----------|---------|----------|
| 1 | `onNewStrip` | `strips/{stripId}` — onCreate | Yeni fotoğraf: streak güncelle + push notification gönder |
| 2 | `onNewDirectMessage` | `direct_messages/{threadId}/messages/{messageId}` — onCreate | Yeni DM: push notification |
| 3 | `onNewComment` | `strips/{stripId}/comments/{commentId}` — onCreate | Yeni yorum: push notification (rate limited: 10/dk) |
| 4 | `onNewFriendRequest` | `users/{userId}/friendships/{friendId}` — onCreate | Arkadaşlık isteği: push notification |
| 11 | `onUserProfileWrite` | `users/{userId}` — onWrite | Username değişikliği: `usernames` koleksiyonunu güncelle |

### 2.2 Storage Trigger'ları

| # | Fonksiyon | Trigger | Açıklama |
|---|-----------|---------|----------|
| 5 | `onImageUploaded` | Storage — onObjectFinalized | Yeni fotoğraf yüklendi: thumbnail oluştur (200x200, 800x800) + Cloud Vision moderasyon |

### 2.3 Scheduled Functions

| # | Fonksiyon | Zamanlama | Açıklama |
|---|-----------|-----------|----------|
| 6a | `scheduledStripCleanup` | Her gün 03:00 | 30 günden eski strip'leri sil (recursive batch) |
| 6b | `scheduledNotificationCleanup` | Her gün 03:30 | 30 günden eski bildirimleri sil |
| 7 | `generateDailyPrompt` | Her gün 00:05 | Günlük fotoğraf görevi oluştur + topic push |
| 8 | `checkStreakExpiry` | Her gün 04:00 | 48+ saat paylaşım yapılmayan streak'leri sıfırla + bildirim gönder |
| 9 | `weeklySummary` | Her Pazar 18:00 | Haftalık özet push notification (paginated) |

### 2.4 Auth Trigger'ları

| # | Fonksiyon | Trigger | Açıklama |
|---|-----------|---------|----------|
| 10 | `onAccountDeleted` | Auth — onDelete | Cascading delete: tüm kullanıcı verilerini temizle |

---

## 3. Cloud Functions Detay

### 3.1 `onNewStrip` — Streak Güncelleme Algoritması

```
Yeni fotoğraf gönderildi:
  ├── Her alıcı için:
  │   ├── streakId = sort([senderId, receiverId]).join("_")
  │   ├── Transaction başlat:
  │   │   ├── Mevcut streak var mı?
  │   │   │   ├── Evet:
  │   │   │   │   ├── daysDiff = bugün - lastExchangeDate
  │   │   │   │   ├── daysDiff == 0 → streak değişmez (aynı gün)
  │   │   │   │   ├── daysDiff == 1 → streak +1
  │   │   │   │   └── daysDiff > 1  → streak = 1 (sıfırlandı)
  │   │   │   └── friendshipScore hesapla
  │   │   └── Hayır:
  │   │       └── Yeni streak oluştur (streak=1, score hesapla)
  │   └── Transaction commit
  └── Push notification gönder (per-user silent hours + preference check)
```

### 3.2 `onAccountDeleted` — Cascading Delete Sırası

```
1. Kullanıcının strip'leri → yorumları sil → storage dosyaları sil → dokümanı sil
2. Diğer kullanıcıların strip'lerinden receiverIds'den çıkar
3. İki taraflı arkadaşlık dokümanlarını sil
4. Streak'leri sil
5. Bildirimleri sil
6. DM mesajlarını sil
7. Private alt koleksiyonu sil
8. Kullanıcı dokümanını sil
9. Avatar fotoğrafını storage'dan sil
```

### 3.3 `onImageUploaded` — Thumbnail Pipeline

```
Storage'a fotoğraf yüklendi:
  ├── strips/ altında mı? (başka klasörler skip)
  ├── thumbs/ altında mı? (recursion engeli)
  ├── Jimp ile thumbnail oluştur:
  │   ├── 200x200 (widget, watch, küçük önizleme)
  │   └── 800x800 (feed, detay)
  ├── Thumbnail'ları public yap
  ├── Firestore strip dokümanını güncelle (thumbnailUrl, smallThumbnailUrl)
  └── Cloud Vision SafeSearch:
      ├── adult == VERY_LIKELY → flagged: true
      ├── violence == VERY_LIKELY → flagged: true
      └── Başarısız olursa → non-blocking (skip)
```

---

## 4. Firestore Index Gereksinimleri

Aşağıdaki composite index'ler gereklidir (`firestore.indexes.json`):

| Collection | Alanlar | Sorgu Tipi |
|------------|---------|------------|
| `strips` | `senderId` ASC, `timestamp` DESC | Kullanıcının gönderdiği fotoğraflar |
| `strips` | `receiverIds` ARRAY_CONTAINS, `timestamp` DESC | Kullanıcının aldığı fotoğraflar |
| `streaks` | `userIds` ARRAY_CONTAINS, `currentStreak` DESC | Kullanıcının aktif streak'leri |
| `streaks` | `currentStreak` ASC, `lastExchangeDate` ASC | Süresi dolan streak'ler |
| `notifications` | `userId` ASC, `timestamp` DESC | Kullanıcının bildirimleri |
| `notifications` | `timestamp` ASC | Eski bildirim temizliği |
| `direct_messages/messages` | `senderId` ASC, `timestamp` DESC | DM mesajları |

---

## 5. Storage Yapısı

```
Firebase Storage
├── strips/
│   ├── {stripId}.jpg              (orijinal fotoğraf)
│   └── thumbs/
│       ├── {stripId}_200x200.jpg  (küçük thumbnail — widget, watch)
│       └── {stripId}_800x800.jpg  (büyük thumbnail — feed)
└── avatars/
    └── {userId}.jpg               (profil fotoğrafı)
```

---

## 6. Push Notification Tipleri

| Tip | Tetikleyici | Başlık | Gövde | Deep Link |
|-----|-------------|--------|-------|-----------|
| `new_strip` | `onNewStrip` | "anlık." | "{senderName} sana yeni bir an paylaştı." | `stripmate://chat/{stripId}` |
| `direct_message` | `onNewDirectMessage` | "anlık. — {senderName}" | Mesaj metni | `stripmate://dm/{threadId}` |
| `new_comment` | `onNewComment` | "anlık." | "{senderName}: {text}" | `stripmate://chat/{stripId}` |
| `friend_request` | `onNewFriendRequest` | "anlık." | "{requesterName} arkadaş olmak istiyor." | `stripmate://inbox` |
| `daily_prompt` | `generateDailyPrompt` | "anlık. — {emoji} günün görevi" | Görev metni | — |
| `streak_lost` | `checkStreakExpiry` | "anlık. — 💔 Seri Bitti" | "{count} günlük serin sona erdi..." | — |
| `weekly_summary` | `weeklySummary` | "anlık. — haftalık özet 📊" | "bu hafta {sent} an paylaştın, {received} an aldın." | — |

### Bildirim Filtreleme
1. **Per-user Sessiz Saatler**: `quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end` (Turkey timezone UTC+3)
2. **Tip Bazlı Tercih**: `notif_strips`, `notif_dms`, `notif_friends` ayrı ayrı kapatılabilir
3. **Rate Limiting**: Yorumlar için dakikada max 10 bildirim
4. **Invalid Token Cleanup**: Başarısız gönderimlerden sonra otomatik token temizliği

---

## 7. Veri Yaşam Döngüsü

| Veri | Oluşturulma | Güncelleme | Otomatik Silme | Manuel Silme |
|------|-------------|------------|----------------|-------------|
| User | Kayıt | Profil düzenleme | — | Hesap silme (cascade) |
| Strip | Fotoğraf gönderimi | Thumbnail ekleme | 30 gün (scheduled) | Gönderen silebilir |
| Streak | İlk fotoğraf alışverişi | Her paylaşımda (Cloud Function) | — | Hesap silindiğinde |
| DM | Mesaj gönderimi | Okundu/silindi | — | Hesap silindiğinde |
| Notification | Bildirim olayı | Okundu işareti | 30 gün (scheduled) | Kullanıcı silebilir |
| Daily Prompt | Her gün 00:05 | — | — | — |
| Username | Profil oluşturma | Username değişikliği | — | Hesap silindiğinde |
