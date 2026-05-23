# Analytics Dashboard Setup

Bu rehber StripMate iOS app'inin Firebase Analytics + Crashlytics entegrasyonunu doğrulamak ve aktivasyon/retention dashboard'larını kurmak için.

---

## 1. Doğrulama (10 dakika)

### Firebase Console — Analytics → DebugView

1. Cihazda terminal açıp:
   ```bash
   xcrun simctl shell booted launchctl debug --enable-debug-environment-variable FIREBASE_ANALYTICS_DEBUG_ENABLED=1
   ```
   veya **Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch**:
   ```
   -FIRDebugEnabled
   ```

2. Uygulamayı çalıştır
3. Firebase Console → Analytics → DebugView → cihazını seç
4. App içinde tıkla, atla, scroll yap → eventler real-time gözükmeli

### Beklenen event'ler (ilk dakika)

| Event | Ne zaman |
|---|---|
| `sm_app_launch` | Cold start |
| `sm_onboarding_started` | İlk açılış |
| `sm_onboarding_completed` veya `sm_onboarding_skipped` | Page 4 / atla |
| `sm_signup_started` | "kayıt ol" tıklama |
| `sm_signup_step_completed` (param: step=0,1,2) | Her step ileri |
| `sm_signup_completed` | Hesap oluşturuldu |
| `sm_friend_gate_shown` | Gate ekranı |
| `sm_friend_gate_passed` (method=request_sent/qr/accepted/skip) | Gate geçildi |

Bunlardan biri DebugView'da gözükmüyorsa → ilgili kod yolu çalışmamış demek, code path'i debug et.

---

## 2. Activation Funnel (Firebase Console → Funnels)

**Funnel: signup → first photo (kritik aktivasyon yolu)**

Adımlar:
1. `sm_app_launch`
2. `sm_signup_started`
3. `sm_signup_completed`
4. `sm_friend_gate_passed`
5. `sm_first_photo_sent`

**Hedef metrikler:**
- 1→2: %30+ (yüksek = ASO + landing iyi)
- 2→3: %50+ (yüksek = signup friction düşük)
- 3→4: %60+ (kritik — friend gate'in fail rate)
- 4→5: %50+ (kritik — kullanıcı core loop'a giriyor mu)

**Toplam 1→5: %5+ minimum** (sektör ortalaması). %2 altıysa funnel'da en zayıf step'e odaklan.

---

## 3. Retention Cohorts (Firebase Console → Audiences)

**Custom Audience'lar oluştur:**

1. **Activated Users** — `sm_first_photo_sent` event'ini ≥1 kez tetikleyenler
2. **Engaged Users** — son 7 günde ≥2 photo gönderenler
3. **Power Users** — `sm_streak_increased` ≥3 kez tetikleyenler
4. **At-Risk** — `sm_app_launch` son 5 günde, ama photo göndermedi

Her audience için **N-day retention** ölç:
- D1, D7, D30 retention dashboard'ları
- Hedef: D1 ≥40%, D7 ≥20%, D30 ≥10%

---

## 4. Crashlytics Doğrulama

1. Firebase Console → Crashlytics
2. **Crash-free users** ≥%99.5 hedef (bunun altıysa ALARM)
3. **Custom keys** ekle her crash report'a:
   ```swift
   Crashlytics.crashlytics().setCustomValue(userId, forKey: "user_id")
   Crashlytics.crashlytics().setCustomValue(currentTab.rawValue, forKey: "current_tab")
   ```
   Şu an bu kod yok — ekle.

4. Test crash:
   ```swift
   #if DEBUG
   Button("Test Crash") {
       fatalError("Test crash")
   }
   #endif
   ```

---

## 5. Önemli Custom Dashboard'lar

### Dashboard: Friend Gate Performance
- `sm_friend_gate_shown` → `sm_friend_gate_passed` ratio
- Method breakdown (request_sent vs qr vs skip vs accepted)
- `sm_friend_gate_help_opened` count (yardım ihtiyacı göstergesi)
- `sm_friend_gate_skipped` count (soft-exit kullanım oranı)

### Dashboard: Signup Drop-off
- `sm_signup_step_completed` step=0 vs step=1 vs step=2 ratio
- `sm_signup_abandoned` at_step parameter histogram

### Dashboard: Permission Acceptance
- `sm_notif_perm_prompted` → granted/denied ratio
- Kabul oranı %50 altıysa: prompt anını/text'ini değiştir

### Dashboard: Photo Send Health
- `sm_send_photo` günlük volume
- `sm_send_photo_failed` / `sm_send_photo` ratio (%2 üstü = sorun)
- `sm_send_photo_retried` count

---

## 6. Alarm Kurma (Firebase Console → Custom Alerts)

Otomatik mail alarmı:
- **Crash-free rate < %99**
- **Signup completion rate düşüşü > %20** (week-over-week)
- **`sm_send_photo_failed` günlük > 100**

---

## 7. BigQuery Export (opsiyonel ama güçlü)

Firebase Analytics → BigQuery export açılırsa:
- Custom SQL ile cohort analizleri
- Retention curve hesaplama
- Funnel breakdown (Firebase Console limitlidir)

```bash
# Project Settings → Integrations → BigQuery → Link
# Daily streaming export açılır
```

Sonra:
```sql
-- Örnek: D7 retention by signup week
SELECT
  EXTRACT(WEEK FROM PARSE_TIMESTAMP('%Y%m%d', user_first_touch_date)) AS signup_week,
  COUNT(DISTINCT user_pseudo_id) AS new_users,
  COUNT(DISTINCT IF(
    DATE_DIFF(event_date, PARSE_DATE('%Y%m%d', user_first_touch_date), DAY) BETWEEN 7 AND 14,
    user_pseudo_id, NULL
  )) AS d7_retained
FROM `stripmate-app.analytics_*.events_*`
WHERE event_name = 'sm_app_launch'
GROUP BY signup_week
ORDER BY signup_week DESC;
```

---

## 8. Aksiyona Geçme Önceliği

Veri gelmeye başladıktan sonra **bu sırayla** bak:

1. **Crash-free rate** — %99'un altıysa her şeyden önce stabilite
2. **Signup completion** — %50'nin altıysa signup'ı yumuşatmaya devam
3. **Friend gate pass rate** — %60'ın altıysa cold-start çözümlerini önceliklendir
4. **D1 retention** — %30'un altıysa first-photo deneyimi sorunlu
5. **D7 retention** — %15'in altıysa engagement features (streak, prompt) zayıf

---

## 9. Dosya Konumu

Bu app'teki tüm event tanımları:
- `StripMate/Services/Analytics/AnalyticsService.swift` → `AnalyticsEvent` enum

Yeni event eklerken:
1. Enum'a ekle (`sm_` prefix)
2. Bu dökümana ekle
3. Tetiklendiği yere kod ekle
4. Firebase Console → Custom Definitions → Register Event (Custom Definitions limit: 25 conversion events)

---

**Son söz:** Veri toplamadan optimize etme. Bir hafta event'lerin akmasını bekle, sonra dashboard'ları kur, sonra hipotez test et.
