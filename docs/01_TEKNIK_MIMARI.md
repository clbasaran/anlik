# 🏗️ anlık. (StripMate) — Teknik Mimari Dokümantasyonu

> **Versiyon:** 2.0.0 | **Tarih:** 6 Mart 2026 | **Platform:** iOS 18+ / watchOS 26+

---

## 1. Proje Genel Bakış

**anlık.**  arkadaşlar arasında anlık fotoğraf paylaşımı ve streak sistemiyle bağlantıyı güçlendiren bir sosyal medya uygulamasıdır. BeReal/Locket/Snapchat benzeri bir deneyim sunar.

### Hedef Kitle
- 16+ yaş (İspanya lansman politikasıyla uyumlu)
- Türkçe lokalizasyon (birincil dil)
- iPhone + Apple Watch kullanıcıları

### Temel Özellikler
| Özellik | Açıklama |
|---------|----------|
| 📸 Anlık Fotoğraf Paylaşımı | Kamera ile çek, filtre/çizim ekle, arkadaşlara gönder |
| 🔥 Streak Sistemi | Günlük paylaşım serisi, friendship tier'ları (New Friend → Soulmate) |
| 💬 Direkt Mesajlaşma | Fotoğraflara yorum + 1:1 DM |
| 🏆 Gamification | Başarımlar, liderlik tablosu, günlük görevler (daily prompt) |
| 🗺️ Konum Haritası | Fotoğrafların çekildiği konumları haritada görüntüleme |
| ⌚ Apple Watch | Companion app — streak, fotoğraf, günün görevi |
| 🔔 Push Notifications | FCM tabanlı bildirimler + in-app banner |
| 📱 Widget | Home screen widget (son fotoğraf, streak, daily prompt) |
| 🎨 Live Activity | Fotoğraf yükleme progress'i Dynamic Island'da |

---

## 2. Mimari Pattern

### MVVM + Repository + Actor

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI — 39 ekran)                       │
├─────────────────────────────────────────────┤
│               ViewModels                     │
│  (@Observable, @MainActor — 8 ViewModel)    │
├─────────────────────────────────────────────┤
│             Repositories                     │
│  (Protocol-based DI — DependencyContainer)  │
├─────────────────────────────────────────────┤
│               Services                       │
│  (Swift Actors — thread-safe business logic)│
├─────────────────────────────────────────────┤
│            Firebase Backend                  │
│  (Firestore + Storage + Auth + FCM)         │
└─────────────────────────────────────────────┘
```

### Concurrency Model
- **Swift Concurrency**: `async/await` tüm projede kullanılıyor
- **Swift Actors**: `AuthService`, `PhotoService`, `CacheService`, `ChatService`, `FriendshipService`, `DailyPromptService`, `SwiftDataSyncService`, `StreakService` — hepsi `actor` olarak tanımlanmış
- **@MainActor**: Tüm ViewModel'ler `@MainActor` ile işaretli
- **@Observable macro**: iOS 17+ Observation framework kullanılıyor (Combine yerine)

---

## 3. Target Yapısı

| Target | Bundle ID | Versiyon | Platform | Açıklama |
|--------|-----------|----------|----------|----------|
| **StripMate** | `com.celalbasaran.stripmate` | 2.0.0 | iOS 18+ | Ana uygulama |
| **StripMateWidget** | `com.celalbasaran.stripmate.widget` | 1.0.25 (Build 26) | iOS 18+ | WidgetKit extension |
| **StripMateNotificationService** | `com.celalbasaran.stripmate.nse` | 1.0 (Build 1) | iOS 18+ | Notification Service Extension |
| **StripMateWatch Watch App** | `com.celalbasaran.stripmate.watchkitapp` | — | watchOS 26+ | Apple Watch companion |
| **StripMateAdmin** | — | — | macOS | Swift Package — admin panel |
| **StripMateTests** | — | — | iOS | XCTest target |

> ⚠️ **KRİTİK:** Widget ve NSE versiyonları ana app ile eşleşmiyor → App Store reddi riski!

---

## 4. Dosya Yapısı (Kaynak Dosyalar)

### Ana App — 97 Swift Dosyası

```
StripMate/
├── App/
│   └── StripMateApp.swift          (543 satır — AppDelegate, SwiftData, Router)
├── Core/
│   ├── ViewModels/                 (8 ViewModel)
│   │   ├── AuthViewModel.swift
│   │   ├── CameraViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── DirectMessageViewModel.swift
│   │   ├── FriendsListViewModel.swift
│   │   ├── HistoryViewModel.swift
│   │   ├── InboxViewModel.swift
│   │   └── NotificationsViewModel.swift
│   └── Views/                      (39 View)
│       ├── MainTabView.swift       (Ana tab navigasyonu)
│       ├── MainCameraView.swift    (Kamera — ana ekran)
│       ├── AuthView.swift          (Giriş/Kayıt)
│       ├── FriendsListView.swift   (1006 satır — en büyük view)
│       ├── HistoryView.swift       (Fotoğraf geçmişi)
│       ├── ChatView.swift          (Fotoğraf yorumları)
│       ├── DirectMessageView.swift (1:1 mesajlaşma)
│       ├── SettingsView.swift      (Ayarlar hub)
│       ├── PhotoDetailView.swift   (Detay ekranı, sol alt köşede konum kapsülü, minimalist)
│       ├── StripLocationMapView.swift (Harita popup, monokrom, minimalist, konum gösterimi)
│       ├── ... (35 view daha)
│       └── ConsentView.swift       (KVKK onay)
├── Models/                         (17 Model)
│   ├── User.swift                  (@Model — SwiftData)
│   ├── Friend.swift                (@Model — SwiftData)
│   ├── Strip.swift                 (@Model — SwiftData)
│   ├── Streak.swift                (Friendship tier sistemi)
│   ├── UserProfile.swift           (Firestore profil)
│   ├── PhotoMetadata.swift
│   ├── DirectMessage.swift
│   ├── Achievement.swift
│   ├── DailyPrompt.swift
│   ├── WatchModels.swift
│   └── ... (7 model daha)
├── Services/                       (16 Servis)
│   ├── Auth/AuthService.swift      (606 satır — login, register, profil, token)
│   ├── Photo/PhotoService.swift    (Upload, download, thumbnail)
│   ├── Camera/CameraManager.swift  (AVFoundation, flash, zoom)
│   ├── Chat/ChatService.swift      (Yorumlar + DM)
│   ├── Friends/FriendshipService.swift
│   ├── Streak/StreakService.swift   (Real-time Firestore listener)
│   ├── Cache/CacheService.swift    (Disk + memory cache)
│   ├── Sync/SwiftDataSyncService.swift
│   ├── Prompt/DailyPromptService.swift
│   ├── Notifications/AppNotificationService.swift
│   ├── Network/NetworkMonitor.swift (NWPathMonitor)
│   ├── Analytics/AnalyticsService.swift
│   ├── Analytics/CrashReporter.swift
│   ├── LiveActivityManager.swift
│   ├── Watch/WatchSessionManager.swift
│   ├── DI/DependencyContainer.swift
│   └── Repositories/Repositories.swift
└── Utils/                          (17 Utility)
    ├── AppConstants.swift
    ├── Brand.swift
    ├── LocationManager.swift
    ├── CachedAsyncImage.swift
    ├── Haptics.swift
    ├── SoundManager.swift
    └── ... (11 utility daha)
```

### Extension'lar
```
StripMateWidget/          (4 dosya — 3 widget tipi)
StripMateNotificationService/ (1 dosya — rich notification)
StripMateWatch Watch App/ (10 dosya — companion app)
StripMateAdmin/           (14 dosya — macOS admin panel)
```

---

## 5. Veri Katmanı

### 5.1 Firebase Backend

| Servis | Kullanım |
|--------|----------|
| **Firebase Auth** | E-posta + Apple Sign-In |
| **Cloud Firestore** | Ana veritabanı (users, strips, streaks, friendships, chats, reports, daily_prompts) |
| **Cloud Storage** | Fotoğraf depolama (orijinal + thumbnail) |
| **Cloud Messaging (FCM)** | Push notification (topic: `daily_prompt`) |
| **App Check** | DeviceCheck (production) / Debug provider (development) |
| **Cloud Functions** | `onNewStrip` (streak güncelleme), hesap yönetimi |

### 5.2 Firestore Şeması

```
├── users/{userId}
│   ├── displayName, username, email, avatarUrl, inviteCode, bio, statusEmoji
│   ├── consent: { kvkk, privacy, terms, timestamp }
│   ├── private/{docId}          (hassas veriler)
│   ├── friendships/{friendId}   (isPending, requesterId, timestamp)
│   └── blocked/{blockedId}
├── strips/{stripId}
│   ├── senderId, imageUrl, thumbnailUrl, timestamp
│   ├── latitude, longitude, cityName
│   ├── recipientIds[], reactions{}
│   └── comments/{commentId}
├── streaks/{streakId}
│   ├── userIds[], currentStreak, longestStreak
│   ├── totalExchanges, friendshipScore
│   ├── lastExchangeDate, lastSenderId
│   └── (Server-side güncelleme — Cloud Function)
├── directMessages/{threadId}/messages/{messageId}
├── daily_prompts/{promptId}
├── reports/{reportId}
└── achievements/{achievementId}
```

### 5.3 Lokal Depolama

| Teknoloji | Kullanım |
|-----------|----------|
| **SwiftData** | `User`, `Friend`, `Strip` — offline-first cache |
| **App Group** | Widget ve ana app arasında shared storage |
| **UserDefaults** | Küçük ayarlar, pinned friend, theme, onboarding flag |
| **URLCache** | 50MB memory + 150MB disk — fotoğraf cache |
| **Firestore Offline** | 100MB persistent cache |

### 5.4 Güvenlik Kuralları (176 satır)

- Tüm okuma/yazma işlemleri `request.auth != null` kontrolü gerektirir
- Kullanıcılar sadece kendi profillerini düzenleyebilir
- Bio max 60 karakter, statusEmoji max 4 karakter (server-side validation)
- Consent alanı bir kez set edildikten sonra kullanıcı tarafından değiştirilemez
- Arkadaşlık işlemleri sadece ilgili iki kullanıcı tarafından yapılabilir
- `timestamp` server timestamp zorunluluğu (backdating engeli)
- Reports collection: write-only (kullanıcılar), read-only (admin)
- Admin custom claim ile ayrıcalıklı erişim

---

## 6. Dependency Graph

### Swift Package Dependencies
| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| Firebase iOS SDK | 12.10.0 | Auth, Firestore, Storage, Messaging, App Check |
| GoogleAppMeasurement | 12.10.0 | Analytics |
| GoogleAdsOnDeviceConversion | 3.x | Reklam dönüşüm |
| AppCheck | 11.2.0 | Device attestation |
| abseil-cpp-binary | 1.2024072200.0 | gRPC dependency |
| grpc-binary | — | Firestore transport |

### Sistem Framework'leri
```swift
SwiftUI, SwiftData, WidgetKit, AVFoundation, CoreLocation,
WatchConnectivity, MapKit, UserNotifications, NWPathMonitor,
ActivityKit (Live Activity), AppIntents, CryptoKit
```

---

## 7. Bildirim Sistemi

### Push Notification Akışı
```
Cloud Function (onNewStrip) → FCM → APNs → iOS
                                         ├── Foreground: In-app banner (custom)
                                         ├── Background: Widget refresh + badge
                                         └── Tap: Deep link → stripmate://chat/{id}
```

### Deep Link Şeması
| URL | Hedef |
|-----|-------|
| `stripmate://chat/{stripId}` | Fotoğraf chat ekranı |
| `stripmate://dm/{threadId}` | Direkt mesaj |
| `stripmate://inbox` | Gelen kutusu |
| `stripmate://camera` | Kamera (widget'tan) |

### Bildirim Tipleri
- `new_strip` — Yeni fotoğraf paylaşımı
- `new_comment` — Yeni yorum
- `direct_message` — Direkt mesaj (aktif DM ekranındaysa bastırılır)
- `friend_request` — Arkadaşlık isteği

---

## 8. Widget Sistemi

### 3 Widget Tipi
1. **LatestStripWidget** — Son paylaşılan fotoğraf (small/medium/large/accessoryRectangular/accessoryCircular)
2. **StreakWidget** — Streak sayısı ve arkadaş bilgisi
3. **DailyPromptWidget** — Günün fotoğraf görevi

### Widget Refresh Stratejisi
- **Throttle**: 5 dakika minimum aralık (Apple'ın ~40-70 günlük bütçesi korunur)
- **Push-triggered**: `new_strip` push gelince widget yenilenir
- **App lifecycle**: `didBecomeActive` ve `willResignActive`'de throttled reload

### Widget Controls (iOS 18)
- `CameraControl` — Widget'tan doğrudan kamera açma
- `OpenAppIntent` — App'i açma

---

## 9. Apple Watch Companion App

### Mimari
```
StripMateWatch Watch App/
├── StripMateWatchApp.swift    (@main entry point)
├── ContentView.swift          (State-based page navigation)
├── Models/WatchModels.swift   (WatchStreak, WatchPhoto, WatchPrompt)
├── Services/
│   ├── PhoneSessionManager.swift  (WCSession — Watch side)
│   └── WatchDataStore.swift       (ObservableObject data store)
├── Views/
│   ├── StreakDashboardView.swift   (Streak listesi + detay)
│   ├── LatestPhotoView.swift      (Son fotoğraf thumbnail)
│   └── DailyPromptCardView.swift  (Günün görevi)
└── Complications/
    ├── WatchComplications.swift   (Complication widget'ları)
    └── WatchWidgetBundle.swift
```

### İletişim: WatchConnectivity
- **iPhone → Watch**: `sendMessage` (sync payload — streaks, photos, prompt)
- **Watch → iPhone**: `sendMessage` (sync request, camera open request)
- Fotoğraf thumbnail'ı payload içinde base64 olarak gönderiliyor
- Reachability monitoring ile bağlantı durumu takibi

---

## 10. Gamification Sistemi

#### Yeni Tier Sistemi (2026)
| Seviye (Tier) | Puan Aralığı | SF Symbol |
|--------------|-------------|-----------|
| Tanıdık      | 0-49        | circle.dotted |
| Muhabbet     | 50-149      | cup.and.saucer.fill |
| Yakın        | 150-349     | link |
| Sırdaş       | 350-699     | key.fill |
| Kadim        | 700+        | infinity |

- Tüm tier ikonları ve metinleri monokrom, minimalist ve Türkçe.
- Kutlama animasyonları: SF Symbol ikonları ile confetti.

### Streak Mekanizması
| Tier | Friendship Score | Emoji |
|------|-----------------|-------|
| New Friend | 0-49 | 🌱 |
| Casual | 50-149 | 😊 |
| Close Friend | 150-349 | ⭐ |
| Best Friend | 350-699 | 💛 |
| Soulmate | 700+ | 💎 |

### Streak Kuralları
- Günlük paylaşım → streak +1
- 24 saat paylaşım yapılmazsa streak sıfırlanır
- `friendshipScore` Cloud Function ile hesaplanır (manipülasyon engeli)
- `isExpiringSoon` özelliği ile uyarı gösterimi

### Başarımlar (Achievements)
- Fotoğraf sayısı milestone'ları
- Streak uzunluğu başarımları
- Arkadaş sayısı hedefleri

---

## 11. Güvenlik Özellikleri

| Özellik | Uygulama |
|---------|----------|
| **Firebase App Check** | DeviceCheck (prod) / Debug (dev) |
| **Firestore Rules** | 176 satır — role-based access control |
| **Server-side Streak** | Cloud Function ile — client manipülasyonu engellenir |
| **KVKK/GDPR Consent** | `ConsentView` — açık rıza alınır, Firestore'da saklanır |
| **Fresh Install Detection** | Keychain + UserDefaults ile re-install algılama |
| **Content Moderation** | Cloud Vision API (potansiyel — Cloud Functions'da) |
| **Rate Limiting** | Widget reload throttle (5 dk minimum) |
| **Input Validation** | Bio ≤60 char, emoji ≤4 char (client + server) |
| **Block/Report** | Kullanıcı engelleme ve şikâyet sistemi |

---

## 12. Admin Panel (macOS)

Swift Package olarak geliştirilmiş macOS admin aracı:
- Kullanıcı yönetimi (listeleme, silme, admin atama)
- Fotoğraf moderasyonu (strip listesi, silme)
- Rapor yönetimi (şikâyetleri görüntüleme)
- Dashboard (istatistikler)
- Push bildirim gönderme

---

## 13. Test Altyapısı

- **XCTest**: 900+ satır test dosyası
- **Mock Repository'ler**: `MockUserRepository`, `MockFriendRepository`, `MockStripRepository`, `MockChatRepository`
- **DependencyContainer.reset()**: Test izolasyonu
- Test coverage alanları: Model testleri, ViewModel testleri, streak hesaplama, seri süreleri

---

## 14. Performans Optimizasyonları

| Alan | Strateji |
|------|----------|
| **Fotoğraf** | Thumbnail (max 200px) + orijinal ayrı yükleme |
| **Cache** | 3 katmanlı: Memory (50MB) + Disk (150MB) + Firestore offline (100MB) |
| **LazyVStack** | Büyük listeler lazy rendering |
| **Widget Budget** | 5 dk throttle ile günlük bütçe korunması |
| **SwiftData** | App Group shared DB — widget ile paylaşım |
| **Offline-first** | Firestore persistent cache + SwiftData sync |
| **Image Compression** | JPEG compression (0.7 quality) before upload |
