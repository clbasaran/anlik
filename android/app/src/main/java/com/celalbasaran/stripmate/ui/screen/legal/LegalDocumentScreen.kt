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
ANLIK. GİZLİLİK POLİTİKASI
Son güncelleme: 23 Mart 2026
Versiyon: 1.1.0

1. VERİ SORUMLUSU

Bu Gizlilik Politikası, anlık. mobil uygulaması ("Uygulama") tarafından toplanan kişisel verilerin işlenmesine ilişkin bilgileri içerir.

2. TOPLANAN VERİLER

2.1. Hesap Bilgileri:
- E-posta adresi
- Görünen ad ve kullanıcı adı
- Doğum tarihi (yaş doğrulaması için)
- Profil fotoğrafı (isteğe bağlı)
- Biyografi (isteğe bağlı)

2.2. İçerik Verileri:
- Çekilen ve paylaşılan fotoğraflar
- Mesajlar ve yorumlar

2.3. Teknik Veriler:
- Cihaz bilgileri (işletim sistemi sürümü, cihaz modeli)
- Crash raporları
- Push notification tokenları

2.4. Konum Verileri (İsteğe Bağlı):
- Fotoğraf çekim konumu (kullanıcı izin verirse)
- Şehir adı (reverse geocoding)

3. VERİLERİN İŞLENME AMAÇLARI

3.1. Hesap oluşturma ve kimlik doğrulama
3.2. Fotoğraf paylaşım hizmetinin sunulması
3.3. Push bildirimleri gönderilmesi
3.4. İçerik moderasyonu (Cloud Vision API - otomatik)
3.5. Uygulama performansının iyileştirilmesi
3.6. Güvenlik ve dolandırıcılık önleme
3.7. Yasal yükümlülüklerin yerine getirilmesi

4. VERİ PAYLAŞIMI

4.1. Verileriniz aşağıdaki üçüncü taraf hizmetlerle paylaşılabilir:
- Google Firebase (altyapı, kimlik doğrulama, veritabanı, depolama)
- Google Cloud Vision API (içerik moderasyonu)
- Google Cloud Messaging / FCM (bildirimler)
- Google Maps (konum hizmetleri)

4.2. Verileriniz reklam amacıyla üçüncü taraflarla paylaşılmaz.

4.3. Yasal zorunluluk halinde yetkili makamlarla veri paylaşımı yapılabilir.

5. VERİ SAKLAMA SÜRESİ

5.1. Fotoğraflar: Paylaşım tarihinden itibaren 30 gün (otomatik silme)
5.2. Hesap verileri: Hesap aktif olduğu sürece
5.3. Hesap silme sonrası: Tüm veriler derhal ve kalıcı olarak silinir
5.4. Crash raporları: 90 gün

6. VERİ GÜVENLİĞİ

6.1. Verileriniz Firebase altyapısında şifreli olarak saklanır.
6.2. Tüm veri iletimi HTTPS/TLS ile şifrelenir.
6.3. FCM tokenları private subcollection'da korunur.
6.4. Erişim kontrolleri Firebase Security Rules ile yönetilir.

7. KULLANICI HAKLARI

7.1. Verilerinize erişim talep etme
7.2. Verilerinizin düzeltilmesini isteme
7.3. Verilerinizin silinmesini isteme (unutulma hakkı)
7.4. Veri işlenmesine itiraz etme
7.5. Veri taşınabilirliği talep etme

Bu haklarınızı kullanmak için: info@celalbasaran.com

8. ÇOCUKLARIN GİZLİLİĞİ

Uygulama 13 yaşından küçük çocukların kullanımına yönelik değildir. 13 yaşından küçük olduğunu tespit ettiğimiz kullanıcıların hesapları silinecektir.

9. ÇEREZ POLİTİKASI

Uygulama web tabanlı çerez kullanmaz. Firebase SDK'ları cihaz üzerinde yerel depolama kullanabilir.

10. DEĞİŞİKLİKLER

Bu Gizlilik Politikası'nda yapılacak değişiklikler Uygulama içinden bildirilecektir. Değişiklikler sonrası Uygulamayı kullanmaya devam etmeniz, güncel politikayı kabul ettiğiniz anlamına gelir.

İletişim: info@celalbasaran.com
    """.trimIndent()

    val termsOfService = """
ANLIK. KULLANIM KOŞULLARI
Son güncelleme: 23 Mart 2026
Versiyon: 1.1.0

1. HİZMET TANIMI

anlık., kullanıcıların arkadaşlarıyla anlık fotoğraflar paylaşması için tasarlanmış bir sosyal medya uygulamasıdır.

2. HESAP KURALLARI

2.1. 13 yaşından büyük olmanız gerekir.
2.2. Gerçek ve doğru bilgiler vermelisiniz.
2.3. Hesabınızın güvenliğinden siz sorumlusunuz.
2.4. Bir kişi yalnızca bir hesap oluşturabilir.

3. İÇERİK KURALLARI

Aşağıdaki içerikler kesinlikle yasaktır:
- Uygunsuz, müzir veya yasa dışı içerik
- Taciz, zorbalık veya nefret söylemi
- Spam veya sahte hesaplar
- Telif hakkı ihlali
- Kişisel bilgilerin izinsiz paylaşımı
- Şiddet veya kendine zarar verme içeriği

4. SINIRLAMALAR

4.1. Maksimum 50 arkadaş eklenebilir.
4.2. Fotoğraflar 30 gün sonra otomatik silinir.
4.3. Günlük gönderim limitleri uygulanabilir.

5. İÇERİK MODERASYONU

5.1. Paylaşılan fotoğraflar otomatik içerik moderasyonundan geçer (Google Cloud Vision API).
5.2. Uygunsuz bulunan içerikler otomatik olarak işaretlenir ve incelenir.
5.3. Kurallara aykırı içerik paylaşan kullanıcılar uyarılır veya hesapları askıya alınır.

6. HESAP SONLANDIRMA

Kurallara aykırı davranan hesaplar uyarı yapılmaksızın askıya alınabilir veya silinebilir.

7. SORUMLULUK REDDİ

7.1. Uygulama "olduğu gibi" sunulmaktadır.
7.2. Veri kaybı veya hizmet kesintilerinden sorumluluk kabul edilmez.
7.3. Kullanıcılar arası etkileşimlerden uygulama sorumlu tutulamaz.

8. FİKRİ MÜLKİYET

8.1. Uygulama ve markası Celal Basaran'a aittir.
8.2. Kullanıcılar paylaştıkları içeriğin hakkı kendilerine ait olduğunu kabul eder.

9. UYUŞMAZLIK ÇÖZÜMÜ

9.1. Bu Koşullardan doğan uyuşmazlıklarda Türkiye Cumhuriyeti kanunları uygulanır.

10. DEĞİŞİKLİKLER

Bu koşullar önceden haber verilmeksizin değiştirilebilir. Güncel koşullar uygulama içerisinden erişilebilir.

Sorularınız için: info@celalbasaran.com
    """.trimIndent()
}
