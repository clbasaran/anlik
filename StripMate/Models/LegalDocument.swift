import Foundation

/// Legal document types and their full content for KVKK/GDPR compliance.
/// Version tracked for audit trail — update version when content changes.
public enum LegalDocument: String, CaseIterable, Identifiable, Sendable {
    case termsOfService = "terms_of_service"
    case privacyPolicy = "privacy_policy"
    case kvkk = "kvkk_disclosure"
    case eula = "eula"
    
    public var id: String { rawValue }
    
    /// Current version — increment when content changes
    public static let currentVersion = "1.1.0"
    
    public var title: String {
        switch self {
        case .termsOfService: return "Kullanım Koşulları"
        case .privacyPolicy: return "Gizlilik Politikası"
        case .kvkk: return "KVKK Aydınlatma Metni"
        case .eula: return "Son Kullanıcı Lisans Sözleşmesi (EULA)"
        }
    }
    
    public var icon: String {
        switch self {
        case .termsOfService: return "doc.text"
        case .privacyPolicy: return "lock.shield"
        case .kvkk: return "person.badge.shield.checkmark"
        case .eula: return "signature"
        }
    }
    
    public var content: String {
        switch self {
        case .termsOfService: return Self.termsOfServiceText
        case .privacyPolicy: return Self.privacyPolicyText
        case .kvkk: return Self.kvkkText
        case .eula: return Self.eulaText
        }
    }
}

// MARK: - Kullanım Koşulları

extension LegalDocument {
    static let termsOfServiceText = """
    ANLIK. KULLANIM KOŞULLARI
    Son güncelleme: 13 Mart 2026
    Versiyon: 1.1.0

    1. GENEL HÜKÜMLER

    1.1. Bu Kullanım Koşulları ("Koşullar"), anlık. mobil uygulamasını ("Uygulama") kullanımınızı düzenler. Uygulamayı indirip kullanarak bu Koşulları kabul etmiş sayılırsınız.

    1.2. Uygulama, kullanıcıların anlık fotoğraflar çekerek arkadaşlarıyla paylaşmasını sağlayan bir sosyal medya platformudur.

    1.3. Bu Koşullar, Türkiye Cumhuriyeti kanunlarına tabidir.

    2. HESAP OLUŞTURMA VE SORUMLULUKLAR

    2.1. Uygulamayı kullanmak için en az 13 yaşında olmanız gerekmektedir. 13 yaşından küçük olduğu tespit edilen kullanıcıların hesapları silinecektir.

    2.2. Hesap bilgilerinizin doğruluğundan ve güncelliğinden siz sorumlusunuz.

    2.3. Hesabınızın güvenliğinden siz sorumlusunuz. Şifrenizi üçüncü kişilerle paylaşmamanız gerekmektedir.

    2.4. Hesabınız üzerinden gerçekleştirilen tüm işlemlerden siz sorumlusunuz.

    3. KABUL EDİLEBİLİR KULLANIM

    3.1. Aşağıdaki içerikleri paylaşmak kesinlikle yasaktır:
    - Müstehcen, pornografik veya cinsel içerikli materyaller
    - Nefret söylemi, ırkçılık, ayrımcılık içeren içerikler
    - Şiddet, terör veya yasa dışı faaliyetleri teşvik eden içerikler
    - Başkalarının fikri mülkiyet haklarını ihlal eden içerikler
    - Kişisel bilgileri izinsiz paylaşma (doxxing)
    - Spam, dolandırıcılık veya yanıltıcı içerikler
    - Zararlı yazılım veya kötü amaçlı bağlantılar

    3.2. Diğer kullanıcılara karşı taciz, zorbalık veya tehdit oluşturan davranışlar yasaktır.

    3.3. Uygunsuz içerik veya kötüye kullanıma karşı SIFIR TOLERANS politikamız bulunmaktadır. Yukarıdaki kurallara aykırı davranan kullanıcıların hesapları derhal askıya alınabilir veya kalıcı olarak silinebilir.

    3.4. Uygulamayı tersine mühendislik, decompile veya kaynak kodunu çıkarma girişiminde bulunamazsınız.

    3.5. Otomatik bot, scraper veya benzeri araçlarla Uygulamayı kullanamazsınız.

    4. İÇERİK VE FİKRİ MÜLKİYET

    4.1. Paylaştığınız fotoğrafların telif hakkı size aittir. Ancak Uygulamayı kullanarak, içeriklerinizin Uygulama altyapısı içinde depolanması, iletilmesi ve görüntülenmesi için bize sınırlı, münhasır olmayan bir lisans vermiş olursunuz.

    4.2. anlık. markası, logosu ve tasarımı dahil tüm fikri mülkiyet hakları saklıdır.

    4.3. Paylaşılan fotoğraflar, Cloud Vision API ile otomatik içerik moderasyonuna tabi tutulur. Uygunsuz bulunan içerikler otomatik olarak işaretlenebilir veya kaldırılabilir.

    5. İÇERİK MODERASYONU VE GÜVENLİK

    5.1. Kullanıcılar, uygunsuz buldukları fotoğraf, mesaj veya kullanıcıları uygulama içi raporlama mekanizması aracılığıyla bildirebilir.

    5.2. Kullanıcılar, diğer kullanıcıları engelleme hakkına sahiptir. Engellenen kullanıcının içerikleri engelleyen kişinin akışından anında kaldırılır ve engellenen kullanıcı engelleyen kişiyle iletişim kuramaz.

    5.3. Bildirilen içerikler, geliştirici ekibi tarafından 24 saat içinde incelenir. Uygunsuz bulunan içerikler kaldırılır ve ilgili kullanıcının hesabı askıya alınabilir veya silinebilir.

    5.4. Otomatik içerik filtreleme sistemi (Google Cloud Vision SafeSearch), yüklenen tüm fotoğrafları yetişkinlere yönelik ve şiddet içeren içerik açısından tarar. İhlal tespit edilen içerikler otomatik olarak işaretlenir ve kullanıcı akışlarından gizlenir.

    6. VERİ SAKLAMA VE SİLME

    6.1. Paylaşılan fotoğraflar 30 gün sonra otomatik olarak sunucularımızdan silinir.

    6.2. Hesabınızı istediğiniz zaman Ayarlar > Hesabı Sil seçeneği ile silebilirsiniz. Hesap silme işlemi geri alınamaz ve tüm verileriniz kalıcı olarak silinir.

    6.3. Hesap silme işlemi 6698 sayılı KVKK ve GDPR düzenlemelerine uygun olarak gerçekleştirilir.

    7. SORUMLULUK SINIRLAMASI

    7.1. Uygulama "OLDUĞU GİBİ" ve "MEVCUT HALİYLE" sunulmaktadır. Uygulamanın kesintisiz veya hatasız çalışacağını garanti etmiyoruz.

    7.2. Kullanıcılar arasındaki etkileşimlerden, paylaşılan içeriklerden veya üçüncü taraf hizmetlerden kaynaklanan zararlardan sorumlu değiliz.

    7.3. Uygulamayı kullanmanızdan kaynaklanan doğrudan, dolaylı, arızi, özel veya sonuç olarak ortaya çıkan zararlardan sorumluluğumuz bulunmamaktadır.

    7.4. Kullanıcıların birbirleriyle paylaştığı içeriklerin yasallığından, doğruluğundan ve uygunluğundan ilgili kullanıcılar sorumludur.

    8. HİZMET DEĞİŞİKLİKLERİ

    8.1. Bu Koşulları önceden bildirimde bulunarak değiştirme hakkımız saklıdır. Değişiklikler Uygulama içinden bildirilecektir.

    8.2. Uygulamayı istediğimiz zaman, herhangi bir bildirimde bulunmaksızın askıya alabilir veya sonlandırabiliriz.

    9. UYUŞMAZLIK ÇÖZÜMÜ

    9.1. Bu Koşullardan doğan uyuşmazlıklarda Türkiye Cumhuriyeti kanunları uygulanır.

    9.2. Uyuşmazlıkların çözümünde İstanbul Mahkemeleri ve İcra Daireleri yetkilidir.

    10. İLETİŞİM

    Sorularınız için: info@celalbasaran.com
    """
}

// MARK: - Gizlilik Politikası

extension LegalDocument {
    static let privacyPolicyText = """
    ANLIK. GİZLİLİK POLİTİKASI
    Son güncelleme: 13 Mart 2026
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
    - Emoji reaksiyonları

    2.3. Teknik Veriler:
    - Cihaz bilgileri (iOS sürümü, cihaz modeli)
    - Firebase Analytics verileri (anonim kullanım istatistikleri)
    - Crash raporları (Firebase Crashlytics)
    - Push notification token'ları

    2.4. Konum Verileri (İsteğe Bağlı):
    - Fotoğraf çekim konumu (kullanıcı izin verirse)
    - Şehir adı (reverse geocoding)

    3. VERİLERİN İŞLENME AMAÇLARI

    3.1. Hesap oluşturma ve kimlik doğrulama
    3.2. Fotoğraf paylaşım hizmetinin sunulması
    3.3. Push bildirimleri gönderilmesi
    3.4. İçerik moderasyonu (Cloud Vision API — otomatik)
    3.5. Uygulama performansının iyileştirilmesi
    3.6. Güvenlik ve dolandırıcılık önleme
    3.7. Yasal yükümlülüklerin yerine getirilmesi

    4. VERİ PAYLAŞIMI

    4.1. Verileriniz aşağıdaki üçüncü taraf hizmetlerle paylaşılabilir:
    - Google Firebase (altyapı, kimlik doğrulama, veritabanı, depolama)
    - Google Cloud Vision API (içerik moderasyonu)
    - Apple Push Notification Service (bildirimler)

    4.2. Verileriniz reklam amacıyla üçüncü taraflarla paylaşılmaz.

    4.3. Yasal zorunluluk halinde yetkili makamlarla veri paylaşımı yapılabilir.

    5. VERİ SAKLAMA SÜRESİ

    5.1. Fotoğraflar: Paylaşım tarihinden itibaren 30 gün (otomatik silme)
    5.2. Hesap verileri: Hesap aktif olduğu sürece
    5.3. Hesap silme sonrası: Tüm veriler derhal ve kalıcı olarak silinir
    5.4. Crash raporları: 90 gün
    5.5. Analytics verileri: Anonim, süresiz

    6. VERİ GÜVENLİĞİ

    6.1. Verileriniz Firebase altyapısında şifreli olarak saklanır.
    6.2. Tüm veri iletimi HTTPS/TLS ile şifrelenir.
    6.3. Firebase App Check ile API güvenliği sağlanır.
    6.4. FCM token'ları private subcollection'da korunur.

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
    """
}

// MARK: - KVKK Aydınlatma Metni

extension LegalDocument {
    static let kvkkText = """
    ANLIK. KVKK AYDINLATMA METNİ
    6698 Sayılı Kişisel Verilerin Korunması Kanunu Kapsamında
    Son güncelleme: 13 Mart 2026
    Versiyon: 1.1.0

    1. VERİ SORUMLUSU

    anlık. mobil uygulaması ("Uygulama") olarak, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu sıfatıyla kişisel verilerinizi aşağıda açıklanan amaçlar çerçevesinde işlemekteyiz.

    2. İŞLENEN KİŞİSEL VERİLER

    a) Kimlik Bilgileri: Ad, soyad, kullanıcı adı, doğum tarihi
    b) İletişim Bilgileri: E-posta adresi
    c) Görsel Veriler: Profil fotoğrafı, paylaşılan fotoğraflar
    d) Konum Verileri: Fotoğraf çekim konumu (açık rıza ile)
    e) İşlem Güvenliği Verileri: Cihaz bilgileri, oturum bilgileri, IP adresi
    f) Pazarlama Verileri: Uygulama kullanım istatistikleri (anonim)

    3. KİŞİSEL VERİLERİN İŞLENME AMAÇLARI

    KVKK'nın 5. ve 6. maddeleri kapsamında kişisel verileriniz aşağıdaki amaçlarla işlenmektedir:

    a) Üyelik işlemlerinin gerçekleştirilmesi ve kimlik doğrulama
    b) Uygulama hizmetlerinin sunulması (fotoğraf paylaşımı, mesajlaşma)
    c) Kullanıcı deneyiminin iyileştirilmesi
    d) Bilgi güvenliği süreçlerinin yürütülmesi
    e) İçerik moderasyonu ve topluluk güvenliği
    f) Yasal yükümlülüklerin yerine getirilmesi
    g) Push bildirimleri gönderilmesi (açık rıza ile)

    4. KİŞİSEL VERİLERİN AKTARILMASI

    Kişisel verileriniz, KVKK'nın 8. ve 9. maddeleri uyarınca:

    a) Altyapı hizmetleri kapsamında Google Firebase'e (ABD — yeterli koruma önlemleri ile)
    b) İçerik güvenliği kapsamında Google Cloud Vision API'ye
    c) Bildirim hizmetleri kapsamında Apple Inc.'e
    d) Yasal zorunluluk halinde yetkili kamu kurum ve kuruluşlarına
    
    aktarılabilmektedir.

    5. KİŞİSEL VERİ TOPLAMA YÖNTEMİ VE HUKUKİ SEBEBİ

    Kişisel verileriniz, Uygulama aracılığıyla elektronik ortamda toplanmaktadır.

    Hukuki sebepler:
    - KVKK md. 5/2(a): Kanunlarda açıkça öngörülmesi
    - KVKK md. 5/2(c): Sözleşmenin kurulması ve ifası
    - KVKK md. 5/2(ç): Veri sorumlusunun hukuki yükümlülüğü
    - KVKK md. 5/2(f): Meşru menfaat (güvenlik, dolandırıcılık önleme)
    - KVKK md. 5/1: Açık rıza (konum verileri, push bildirimler)

    6. İLGİLİ KİŞİ HAKLARI (KVKK MD. 11)

    KVKK'nın 11. maddesi kapsamında aşağıdaki haklara sahipsiniz:

    a) Kişisel verilerinizin işlenip işlenmediğini öğrenme
    b) İşlenmişse buna ilişkin bilgi talep etme
    c) İşlenme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme
    d) Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme
    e) Eksik veya yanlış işlenmişse düzeltilmesini isteme
    f) KVKK'nın 7. maddesi çerçevesinde silinmesini veya yok edilmesini isteme
    g) (e) ve (f) bentleri uyarınca yapılan işlemlerin aktarıldığı üçüncü kişilere bildirilmesini isteme
    h) İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme
    i) Kanuna aykırı olarak işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme

    7. BAŞVURU

    Yukarıdaki haklarınızı kullanmak için aşağıdaki yöntemlerle başvurabilirsiniz:
    
    E-posta: info@celalbasaran.com
    Konu: "KVKK Bilgi Talebi"

    Başvurunuz en geç 30 gün içinde ücretsiz olarak sonuçlandırılacaktır.

    8. VERİ SAKLAMA SÜRESİ

    Kişisel verileriniz, işleme amaçları ortadan kalktığında veya hesabınızı sildiğinizde derhal ve geri dönüşü olmayacak şekilde silinir, yok edilir veya anonim hale getirilir.
    """
}

// MARK: - EULA

extension LegalDocument {
    static let eulaText = """
    ANLIK. SON KULLANICI LİSANS SÖZLEŞMESİ (EULA)
    Son güncelleme: 13 Mart 2026
    Versiyon: 1.1.0

    Bu Son Kullanıcı Lisans Sözleşmesi ("EULA"), anlık. mobil uygulamasının ("Uygulama") kullanımınızı düzenleyen yasal bir anlaşmadır.

    1. LİSANS

    1.1. Size Uygulamayı kişisel ve ticari olmayan amaçlarla kullanmanız için sınırlı, münhasır olmayan, devredilemez, geri alınabilir bir lisans verilmektedir.

    1.2. Bu lisans, Uygulamanın size satıldığı anlamına gelmez. Tüm haklar saklıdır.

    2. KISITLAMALAR

    2.1. Uygulamayı kopyalayamaz, değiştiremez, dağıtamaz, satamaz veya kiralayamazsınız.
    2.2. Uygulamayı tersine mühendislik, decompile veya disassemble edemezsiniz.
    2.3. Uygulamanın güvenlik önlemlerini aşmaya çalışamazsınız.
    2.4. Uygulamayı yasa dışı amaçlarla kullanamazsınız.

    3. FİKRİ MÜLKİYET

    3.1. Uygulama ve tüm bileşenleri (kod, tasarım, marka, logo) fikri mülkiyet hakları ile korunmaktadır.
    3.2. "anlık." markası ve logosu tescilli olup izinsiz kullanılamaz.

    4. KULLANICI İÇERİĞİ VE MODERASYON

    4.1. Uygulama, kullanıcıların fotoğraf ve mesaj paylaşmasına olanak tanır. Bu içerikler "kullanıcı tarafından oluşturulan içerik" (UGC) olarak kabul edilir.

    4.2. Uygunsuz içerik veya kötüye kullanıma karşı SIFIR TOLERANS politikamız bulunmaktadır. Müstehcen, şiddet içeren, taciz edici veya yasa dışı içerik paylaşan kullanıcıların hesapları derhal askıya alınır veya kalıcı olarak silinir.

    4.3. Tüm paylaşılan fotoğraflar, otomatik içerik filtreleme sistemi (Google Cloud Vision SafeSearch) tarafından taranır. İhlal tespit edilen içerikler otomatik olarak işaretlenir ve gizlenir.

    4.4. Kullanıcılar, uygunsuz buldukları fotoğraf, mesaj veya kullanıcıları uygulama içi raporlama mekanizması aracılığıyla bildirebilir. Kullanıcılar ayrıca diğer kullanıcıları engelleme hakkına sahiptir; engelleme işlemi ilgili kullanıcının tüm içeriklerini engelleyen kişinin akışından anında kaldırır.

    4.5. Bildirilen içerikler 24 saat içinde incelenir. Uygunsuz bulunan içerikler kaldırılır ve ilgili kullanıcının hesabı askıya alınabilir veya silinebilir.

    5. ÜST SINIR SORUMLULUĞU

    5.1. UYGULAMA "OLDUĞU GİBİ" SUNULMAKTADIR. HERHANGİ BİR GARANTİ VERİLMEMEKTEDİR.

    5.2. UYGULAMANIN KULLANIMINDAN KAYNAKLANAN HİÇBİR DOĞRUDAN, DOLAYLI, ARIZİ, ÖZEL VEYA SONUÇ OLARAK ORTAYA ÇIKAN ZARARDAN SORUMLU DEĞİLİZ.

    5.3. HİÇBİR KOŞULDA, BU SÖZLEŞME KAPSAMINDAKİ TOPLAM SORUMLULUĞUMUZ, SIFIR (0) TL'Yİ AŞMAYACAKTIR.

    6. HESAP FESHİ

    6.1. Bu Sözleşmeyi herhangi bir nedenle, herhangi bir zamanda feshetme hakkını saklı tutarız.
    6.2. Koşulları ihlal etmeniz durumunda hesabınız bildirim yapılmaksızın askıya alınabilir veya silinebilir.
    6.3. Hesabınızı istediğiniz zaman uygulama içi Ayarlar menüsünden silebilirsiniz.

    7. UYGULANACAK HUKUK

    7.1. Bu Sözleşme Türkiye Cumhuriyeti kanunlarına tabidir.
    7.2. Uyuşmazlıklarda İstanbul Mahkemeleri ve İcra Daireleri yetkilidir.

    8. DEĞİŞİKLİKLER

    Bu Sözleşmeyi önceden bildirimde bulunarak değiştirme hakkımız saklıdır.

    9. İLETİŞİM

    info@celalbasaran.com

    Bu Sözleşmeyi kabul ederek, yukarıdaki tüm koşulları okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmiş olursunuz.
    """
}
