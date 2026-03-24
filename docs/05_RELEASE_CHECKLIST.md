# ✅ anlık. (StripMate) — App Store Release Checklist

> **Tarih:** 6 Mart 2026 | **Hedef Versiyon:** 2.0.0

---

## 🔴 KRİTİK — App Store Reddi Riski

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

### 2. Versiyon Numaralarını Eşle
- [ ] StripMateWidget: `MARKETING_VERSION = 2.0.0`, `CURRENT_PROJECT_VERSION = 1`
- [ ] StripMateNotificationService: `MARKETING_VERSION = 2.0.0`, `CURRENT_PROJECT_VERSION = 1`
- [ ] StripMateWatch: Versiyon kontrol et ve eşle
- [ ] Xcode → General → Version ve Build tüm target'larda aynı olmalı

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
- [ ] App Check production modda (DeviceCheck)
- [ ] API anahtarları production değerleri
- [ ] Test verileri temizlendi

### 6. URL'leri Kontrol Et
- [ ] Privacy Policy URL aktif ve erişilebilir
- [ ] Support URL aktif ve erişilebilir
- [ ] Marketing URL aktif (opsiyonel)
- [ ] Yasal dokümanlar (KVKK, Gizlilik, Kullanım Şartları) güncel

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
- [ ] Tüm string'ler Türkçe
- [ ] Info.plist usage description'ları Türkçe
- [ ] Tarih/saat formatı Türkçe locale
- [ ] Sayı formatı Türkçe locale

---

## 📦 App Store Connect Submission

### 13. Metadata Gir
- [ ] App adı: "anlık."
- [ ] Subtitle
- [ ] Açıklama (Türkçe)
- [ ] Anahtar kelimeler (100 karakter)
- [ ] Kategori: Social Networking + Photo & Video
- [ ] Yaş sınıflandırması: 12+ (UGC var)
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
