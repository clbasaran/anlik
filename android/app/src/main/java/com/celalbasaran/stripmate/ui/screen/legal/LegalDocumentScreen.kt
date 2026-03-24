package com.celalbasaran.stripmate.ui.screen.legal

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LegalDocumentScreen(
    title: String,
    content: String,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text(title) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Geri",
                        tint = TextPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = PureBlack,
                titleContentColor = TextPrimary
            )
        )

        // Version badge
        Text(
            text = "v1.0",
            color = TextSecondary.copy(alpha = 0.4f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .padding(bottom = 12.dp)
        )

        HorizontalDivider(color = TextSecondary.copy(alpha = 0.08f))

        // Content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 20.dp)
        ) {
            Text(
                text = content,
                color = TextPrimary.copy(alpha = 0.75f),
                fontSize = 14.sp,
                lineHeight = 22.sp
            )
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

object LegalTexts {
    val privacyPolicy = """
ANLIK. GIZLILIK POLITIKASI
Son guncelleme: 23 Mart 2026
Versiyon: 1.1.0

1. VERI SORUMLUSU

Bu Gizlilik Politikasi, anlik. mobil uygulamasi ("Uygulama") tarafindan toplanan kisisel verilerin islenmesine iliskin bilgileri icerir.

2. TOPLANAN VERILER

2.1. Hesap Bilgileri:
- E-posta adresi
- Görünen ad ve kullanıcı adı
- Doğum tarihi (yaş doğrulaması için)
- Profil fotoğrafı (isteğe bağlı)
- Biyografi (istege bagli)

2.2. Icerik Verileri:
- Çekilen ve paylaşılan fotoğraflar
- Mesajlar ve yorumlar

2.3. Teknik Veriler:
- Cihaz bilgileri (isletim sistemi surumu, cihaz modeli)
- Crash raporlari
- Push notification tokenlari

2.4. Konum Verileri (Istege Bagli):
- Fotoğraf çekim konumu (kullanıcı izin verirse)
- Sehir adi (reverse geocoding)

3. VERILERIN ISLENME AMACLARI

3.1. Hesap olusturma ve kimlik dogrulama
3.2. Fotoğraf paylaşım hizmetinin sunulması
3.3. Push bildirimleri gönderilmesi
3.4. Icerik moderasyonu (Cloud Vision API - otomatik)
3.5. Uygulama performansinin iyilestirilmesi
3.6. Guvenlik ve dolandiricilik onleme
3.7. Yasal yukumluluklerin yerine getirilmesi

4. VERI PAYLASIMI

4.1. Verileriniz asagidaki ucuncu taraf hizmetlerle paylasilabilir:
- Google Firebase (altyapi, kimlik dogrulama, veritabani, depolama)
- Google Cloud Vision API (icerik moderasyonu)
- Google Cloud Messaging / FCM (bildirimler)
- Google Maps (konum hizmetleri)

4.2. Verileriniz reklam amaciyla ucuncu taraflarla paylasilmaz.

4.3. Yasal zorunluluk halinde yetkili makamlarla veri paylasimi yapilabilir.

5. VERI SAKLAMA SURESI

5.1. Fotoğraflar: Paylaşım tarihinden itibaren 30 gün (otomatik silme)
5.2. Hesap verileri: Hesap aktif oldugu surece
5.3. Hesap silme sonrasi: Tum veriler derhal ve kalici olarak silinir
5.4. Crash raporlari: 90 gun

6. VERI GUVENLIGI

6.1. Verileriniz Firebase altyapisinda sifreli olarak saklanir.
6.2. Tum veri iletimi HTTPS/TLS ile sifrelenir.
6.3. FCM tokenlari private subcollection'da korunur.
6.4. Erisim kontrolleri Firebase Security Rules ile yonetilir.

7. KULLANICI HAKLARI

7.1. Verilerinize erisim talep etme
7.2. Verilerinizin duzeltilmesini isteme
7.3. Verilerinizin silinmesini isteme (unutulma hakki)
7.4. Veri islenmesine itiraz etme
7.5. Veri tasinabilirligi talep etme

Bu haklarinizi kullanmak icin: info@celalbasaran.com

8. COCUKLARIN GIZLILIGI

Uygulama 13 yasindan kucuk cocuklarin kullanimina yonelik degildir. 13 yasindan kucuk oldugunu tespit ettigimiz kullanicilarin hesaplari silinecektir.

9. CEREZ POLITIKASI

Uygulama web tabanli cerez kullanmaz. Firebase SDK'lari cihaz uzerinde yerel depolama kullanabilir.

10. DEGISIKLIKLER

Bu Gizlilik Politikasi'nda yapilacak degisiklikler Uygulama icinden bildirilecektir. Degisiklikler sonrasi Uygulamayi kullanmaya devam etmeniz, guncel politikayi kabul ettiginiz anlamina gelir.

Iletisim: info@celalbasaran.com
    """.trimIndent()

    val termsOfService = """
ANLIK. KULLANIM KOSULLARI
Son guncelleme: 23 Mart 2026
Versiyon: 1.1.0

1. HIZMET TANIMI

anlik., kullanıcıların arkadaşlarıyla anlık fotoğraflar paylaşması için tasarlanmış bir sosyal medya uygulamasıdır.

2. HESAP KURALLARI

2.1. 13 yasindan buyuk olmaniz gerekir.
2.2. Gercek ve dogru bilgiler vermelisiniz.
2.3. Hesabinizin guvenliginden siz sorumlusunuz.
2.4. Bir kisi yalnizca bir hesap olusturabilir.

3. ICERIK KURALLARI

Asagidaki icerikler kesinlikle yasaktir:
- Uygunsuz, muzir veya yasa disi icerik
- Taciz, zorbalik veya nefret soylemi
- Spam veya sahte hesaplar
- Telif hakki ihlali
- Kisisel bilgilerin izinsiz paylasimi
- Siddet veya kendine zarar verme icerigi

4. SINIRLAMALAR

4.1. Maksimum 50 arkadaş eklenebilir.
4.2. Fotoğraflar 30 gün sonra otomatik silinir.
4.3. Günlük gönderim limitleri uygulanabilir.

5. ICERIK MODERASYONU

5.1. Paylaşılan fotoğraflar otomatik içerik moderasyonundan geçer (Google Cloud Vision API).
5.2. Uygunsuz bulunan icerikler otomatik olarak isaretlenir ve incelenir.
5.3. Kurallara aykiri icerik paylasan kullanicilar uyarilir veya hesaplari askiya alinir.

6. HESAP SONLANDIRMA

Kurallara aykiri davranan hesaplar uyari yapilmaksizin askiya alinabilir veya silinebilir.

7. SORUMLULUK REDDI

7.1. Uygulama "oldugu gibi" sunulmaktadir.
7.2. Veri kaybi veya hizmet kesintilerinden sorumluluk kabul edilmez.
7.3. Kullanicilar arasi etkilesimlerden uygulama sorumlu tutulamaz.

8. FIKRI MULKIYET

8.1. Uygulama ve markasi Celal Basaran'a aittir.
8.2. Kullanicilar paylastiklari icerigin hakki kendilerine ait oldugunu kabul eder.

9. UYUSMAZLIK COZUMU

9.1. Bu Kosullardan dogan uyusmazliklarda Turkiye Cumhuriyeti kanunlari uygulanir.

10. DEGISIKLIKLER

Bu koşullar önceden haber verilmeksizin değiştirilebilir. Güncel koşullar uygulama içerisinden erişilebilir.

Sorulariniz icin: info@celalbasaran.com
    """.trimIndent()
}
