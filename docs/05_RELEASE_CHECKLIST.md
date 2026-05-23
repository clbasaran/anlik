# ✅ anlık. (StripMate) — App Store Release Checklist

> **Tarih:** 6 Mart 2026 | **Hedef Versiyon:** 2.0.0

---

## 🔴 KRİTİK — Release Blocker

### 1. PrivacyInfo.xcprivacy Oluştur
- [ ] `StripMate/PrivacyInfo.xcprivacy` dosyasını oluştur
- [ ] NSPrivacyAccessedAPITypes beyan et:
  - `NSPrivacyAccessedAPICategoryUserDefaults` (Reason: `CA92.1` — app functionality)
  - `NSPrivacyAccessedAPICategoryFileTimestamp` (Reason: `DDA9.1` — file management)
  - `NSPrivacyAccessedAPICategorySystemBootTime` (Reason: `35F9.1` — measuring elapsed time)
  - `NSPrivacyAccessedAPICategoryDiskSpace` (Reason: `E174.1` — disk space checks)
- [ ] NSPrivacyTracking: false
- [ ] NSPrivacyTrackingDomains: boş array
- [ ] NSPrivacyCollectedDataTypes: privacy labels ile uyumlu
- [ ] Dosyayı Xcode target'a ekle

### 2. Target Versiyonlarını Senkron Tut
- [ ] Main app, widget ve notification service için `MARKETING_VERSION` aynı
- [ ] Main app, widget ve notification service için `CURRENT_PROJECT_VERSION` aynı
- [ ] Info.plist içinde sabit versiyon yerine `$(MARKETING_VERSION)` ve `$(CURRENT_PROJECT_VERSION)` kullanılıyor
- [ ] Xcode → General ekranında target'lar arasında sürüm farkı yok

### 3. Hesap Silme Doğrulaması
- [ ] Settings → Hesap Silme butonu çalışıyor mu?
- [ ] Firestore'da tüm kullanıcı verileri siliniyor mu?
- [ ] Storage'daki fotoğraflar temizleniyor mu?
- [ ] FCM token kaldırılıyor mu?
- [ ] SwiftData'dan kullanıcı verileri siliniyor mu?

---

## 🟡 ÖNEMLİ — Pre-Submission

### 4. Build ve Signing
- [ ] Archive build başarılı (Release configuration)
- [ ] Distribution certificate geçerli
- [ ] Provisioning profile'lar güncel (tüm target'lar)
- [ ] Team ID: `V99XFMU3L7`
- [ ] Code signing: Automatic
- [ ] Entitlements doğru:
  - [ ] Main app: Push (production), Apple Sign-In, App Groups
  - [ ] Widget: App Groups
  - [ ] NSE: App Groups
  - [ ] Watch: Kontrol et

### 5. Firebase & Backend
- [ ] GoogleService-Info.plist production ortamını gösteriyor
- [ ] Firestore rules deploy edildi (production)
- [ ] Storage rules deploy edildi
- [ ] Cloud Functions deploy edildi
- [ ] Deploy, repo içindeki güncel `functions/index.js` üzerinden yapıldı
- [ ] Push token akışı `users/{uid}/private/tokens` üstünden doğrulandı
- [ ] App Check production modda (DeviceCheck)
- [ ] API anahtarları production değerleri
- [ ] Test verileri temizlendi

### 6. URL'leri Kontrol Et
- [ ] Privacy Policy URL aktif ve erişilebilir
- [ ] Support URL aktif ve erişilebilir
- [ ] Marketing URL aktif (opsiyonel)
- [ ] Yasal dokümanlar (KVKK, Gizlilik, Kullanım Şartları) güncel
- [ ] İspanya için `es-ES` destek/gizlilik/şartlar sayfaları erişilebilir
  Taslak kopya: `docs/es-ES/support.md`, `docs/es-ES/privacy-policy.md`, `docs/es-ES/terms-of-service.md`

### 7. Performans Testleri
- [ ] Cold start < 3 saniye
- [ ] Kamera açılma < 1 saniye
- [ ] Fotoğraf yükleme < 5 saniye (Wi-Fi)
- [ ] Memory kullanımı < 200MB normal kullanımda
- [ ] Battery drain kabul edilebilir
- [ ] Offline mode çalışıyor (Firestore cache)
- [ ] Widget düzgün yükleniyor

---

## 🟢 STANDARTr — Kalite Kontrolleri

### 8. Fonksiyonel Testler
- [ ] **Auth**: E-posta kayıt, giriş, Apple Sign-In
- [ ] **Kamera**: Fotoğraf çekimi, ön/arka kamera, flash, zoom
- [ ] **Paylaşım**: Fotoğraf gönderme, recipient seçimi
- [ ] **Streak**: Doğru hesaplanıyor, tier gösterimi doğru
- [ ] **Arkadaşlık**: İstek gönderme, kabul, silme, engelleme
- [ ] **Mesajlaşma**: DM gönderme, yorum, emoji tepki
- [ ] **Bildirimler**: Foreground banner, background badge, tap deep link
- [ ] **Bildirimler**: push izni aç/kapat sonrası `push_enabled` Firestore'a doğru yansıyor
- [ ] **Bildirimler**: FCM token yenilenince `private/tokens` içinde `platform` ve `updatedAt` güncelleniyor
- [ ] **Widget**: Son fotoğraf, streak, daily prompt gösterimi
- [ ] **Watch**: Streak, fotoğraf, günün görevi senkronizasyonu
- [ ] **Harita**: Konum doğru gösteriliyor
- [ ] **Deep Links**: stripmate://chat, dm, inbox, camera
- [ ] **Çizim**: Fotoğraf üzerine çizim ve yazı
- [ ] **Ayarlar**: Tüm alt sayfalar açılıyor

### 9. Edge Case Testleri
- [ ] Ağ bağlantısı kesildiğinde crash yok
- [ ] Kamera izni reddedildiğinde uygun mesaj
- [ ] Konum izni reddedildiğinde uygun fallback
- [ ] Push izni reddedildiğinde uygulama çalışıyor
- [ ] Boş arkadaş listesi → empty state gösterimi
- [ ] Boş fotoğraf geçmişi → empty state gösterimi
- [ ] Çok uzun kullanıcı adı → truncation
- [ ] Düşük disk alanı → uyarı
- [ ] Re-install sonrası → temiz başlangıç

### 10. Cihaz Uyumluluk Testleri
- [ ] iPhone SE (3rd gen) — küçük ekran
- [ ] iPhone 16 Pro Max — büyük ekran
- [ ] iPad (genel uyumluluk, target'ta iPad varsa)
- [ ] Apple Watch Ultra 2 / Series 10
- [ ] iOS 18.0 (minimum)
- [ ] watchOS 26+ (minimum)

### 11. Erişilebilirlik
- [ ] VoiceOver ile temel navigasyon çalışıyor
- [ ] Dynamic Type destekleniyor (sistem font)
- [ ] Contrast oranları yeterli (WCAG AA)
- [ ] Tüm interaktif elemanların accessibilityLabel'ı var
- [ ] Haptic feedback uygun yerlerde

### 12. Lokalizasyon
- [ ] Türkçe ana katalog eksiksiz
- [ ] `es-ES` launch-kritik yüzeyler eksiksiz
- [ ] Info.plist usage description'ları Türkçe + `es-ES`
- [ ] Tarih/saat formatı locale'e göre doğru
- [ ] Sayı formatı locale'e göre doğru

### 12A. İspanya Açılışı Kontrolleri
- [ ] `es-ES` launch-kritik ekranlar doğrulandı: auth, onboarding, kamera, history, friends, notifications
- [ ] İspanya kullanıcıları için ürün içi `16+` yaş kapısı çalışıyor
- [ ] Watch yüzeyleri ve complication isimleri `es-ES` gösteriyor
- [ ] Spain build sweep komutları çalıştırıldı:
  - [ ] `xcodebuild test -scheme StripMate -destination 'id=7EB7DF3E-A7E4-4AAA-8F4B-5F0571987C21' -only-testing:StripMateTests`
  - [ ] `xcodebuild build -scheme StripMate -destination 'id=7EB7DF3E-A7E4-4AAA-8F4B-5F0571987C21' CODE_SIGNING_ALLOWED=NO`
  - [ ] `/bin/zsh -lc "GRADLE_USER_HOME=/Users/celalbasaran/Desktop/Projeler/StripMate/.gradle-home ./gradlew testDebugUnitTest assembleDebug"`
  - [ ] `node --check functions/index.js`

---

## 📦 App Store Connect Submission

### 13. Metadata Gir
- [ ] App adı: "anlık."
- [ ] Subtitle
- [ ] Açıklama (Türkçe)
- [ ] `es-ES` açıklama ve subtitle
- [ ] Anahtar kelimeler (100 karakter)
- [ ] Kategori: Social Networking + Photo & Video
- [ ] Yaş sınıflandırması: 16+ (İspanya politikasıyla uyumlu)
- [ ] Privacy Policy URL
- [ ] Support URL

### 14. Screenshots Yükle
- [ ] iPhone 6.9" (zorunlu) — 5-10 adet
- [ ] iPhone 6.7" (zorunlu) — 5-10 adet
- [ ] Apple Watch — 3-5 adet
- [ ] App Preview Video (opsiyonel — önerilir)

### 15. Privacy Labels
- [ ] "Data linked to you" bölümünü doldur
- [ ] "Data not linked to you" bölümünü doldur
- [ ] Tracking: "No" seç

### 16. Review Information
- [ ] Test hesabı bilgileri
- [ ] Demo notları (kamera gerekliliği vb.)
- [ ] Contact information

### 17. Final Upload
- [ ] Xcode → Archive → Distribute App → App Store Connect
- [ ] Upload başarılı
- [ ] Release archive öncesi temiz komutla son build alındı:
  - [ ] `xcodebuild -scheme StripMate -configuration Release -destination 'generic/platform=iOS' archive`
- [ ] TestFlight internal test (en az 24 saat)
- [ ] Crash-free rate > 99%
- [ ] External beta test (opsiyonel)
- [ ] Submit for Review

---

## 📝 Post-Launch

### 18. İzleme
- [ ] Crash monitoring (Firebase Crashlytics)
- [ ] User feedback izleme
- [ ] App Store review'ları takip
- [ ] Analytics dashboard kontrol
- [ ] Server-side hata logları

### 19. Hızlı Tepki Planı
- [ ] Kritik crash → hotfix release planı
- [ ] App Store reddi → review notes'a göre düzeltme
- [ ] Negatif review'lar → müşteri destek yanıtı
