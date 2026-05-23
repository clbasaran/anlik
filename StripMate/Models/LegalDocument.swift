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
        title(for: Self.currentLanguageCode)
    }

    public func title(for languageCode: String?) -> String {
        switch Self.normalizedLanguageCode(languageCode) {
        case "es":
            switch self {
            case .termsOfService: return "Condiciones de uso"
            case .privacyPolicy: return "Politica de privacidad"
            case .kvkk: return "Aviso de Proteccion de Datos (RGPD)"
            case .eula: return "Acuerdo de licencia (EULA)"
            }
        default:
            switch self {
            case .termsOfService: return "Kullanım Koşulları"
            case .privacyPolicy: return "Gizlilik Politikası"
            case .kvkk: return "KVKK Aydınlatma Metni"
            case .eula: return "Son Kullanıcı Lisans Sözleşmesi (EULA)"
            }
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
        content(for: Self.currentLanguageCode)
    }

    public func content(for languageCode: String?) -> String {
        switch Self.normalizedLanguageCode(languageCode) {
        case "es":
            switch self {
            case .termsOfService: return Self.termsOfServiceTextES
            case .privacyPolicy: return Self.privacyPolicyTextES
            case .kvkk: return Self.kvkkTextES
            case .eula: return Self.eulaTextES
            }
        default:
            switch self {
            case .termsOfService: return Self.termsOfServiceText
            case .privacyPolicy: return Self.privacyPolicyText
            case .kvkk: return Self.kvkkText
            case .eula: return Self.eulaText
            }
        }
    }

    private static var currentLanguageCode: String {
        Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier
    }

    private static func normalizedLanguageCode(_ languageCode: String?) -> String {
        let candidate = (languageCode?.lowercased() ?? currentLanguageCode.lowercased())
        if candidate.hasPrefix("es") { return "es" }
        return "tr"
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

    2.1. Uygulamayı kullanmak için en az 16 yaşında olmanız gerekmektedir. 16 yaşından küçük olduğu tespit edilen kullanıcıların hesapları silinecektir.

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

    Uygulama 16 yaşından küçük bireylerin kullanımına yönelik değildir. 16 yaşından küçük olduğunu tespit ettiğimiz kullanıcıların hesapları silinecektir.

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

// MARK: - Spain Spanish Legal Copy

extension LegalDocument {
    static let termsOfServiceTextES = """
    ANLIK. CONDICIONES DE USO
    Ultima actualizacion: 13 de marzo de 2026
    Version: 1.1.0

    1. SERVICIO

    1.1. Estas Condiciones regulan el uso de la aplicacion movil anlik.
    1.2. anlik. es una red social privada para compartir fotos y videos con tu gente cercana.
    1.3. Al crear una cuenta o usar la app aceptas estas condiciones.

    2. CUENTA Y EDAD

    2.1. Debes tener al menos 16 anos para usar la app.
    2.2. Si detectamos que una cuenta pertenece a una persona menor de 16 anos, podremos suspenderla o eliminarla.
    2.3. Eres responsable de mantener tus datos correctos y de proteger tu cuenta.

    3. USO ACEPTABLE

    3.1. No puedes compartir contenido sexual explicito, violento, ilegal, acosador, fraudulento o que infrinja derechos de terceros.
    3.2. No puedes publicar datos personales de otras personas sin permiso.
    3.3. No puedes usar bots, scrapers ni intentar extraer el codigo fuente o saltarte las medidas de seguridad.

    4. CONTENIDO Y MODERACION

    4.1. Conservas los derechos sobre el contenido que subes.
    4.2. Nos concedes una licencia limitada para almacenar, procesar, mostrar y entregar ese contenido dentro del servicio.
    4.3. Aplicamos moderacion automatica y revision manual para proteger a la comunidad.
    4.4. El contenido denunciado puede ocultarse, revisarse y eliminarse si incumple estas condiciones.

    5. RETENCION Y ELIMINACION

    5.1. Las fotos compartidas se eliminan automaticamente de nuestros servidores a los 30 dias.
    5.2. Puedes borrar tu cuenta desde Ajustes. La eliminacion es permanente y elimina tus datos de producto segun nuestras reglas de retencion.

    6. RESPONSABILIDAD

    6.1. La app se ofrece "tal cual" y "segun disponibilidad".
    6.2. No garantizamos que el servicio funcione sin interrupciones o sin errores.
    6.3. En la medida permitida por la ley, no respondemos por danos indirectos o por interacciones entre usuarios.

    7. LEY APLICABLE

    7.1. Estas condiciones se rigen por la legislacion de Turquia.
    7.2. Los tribunales de Estambul seran competentes para las disputas derivadas de estas condiciones.

    8. CONTACTO

    Para cualquier duda: info@celalbasaran.com
    """

    static let privacyPolicyTextES = """
    ANLIK. POLITICA DE PRIVACIDAD
    Ultima actualizacion: 13 de marzo de 2026
    Version: 1.1.0

    Esta politica de privacidad se redacta conforme al Reglamento General de Proteccion de Datos (RGPD - Reglamento UE 2016/679) y la Ley Organica 3/2018 de Proteccion de Datos Personales y garantia de los derechos digitales (LOPDGDD).

    1. RESPONSABLE DEL TRATAMIENTO

    1.1. Identidad: Celal Basaran (desarrollador independiente).
    1.2. Correo de contacto: info@celalbasaran.com
    1.3. El responsable determina los fines y medios del tratamiento de datos personales recogidos a traves de la aplicacion anlik.

    2. DATOS QUE RECOPILAMOS

    2.1. Datos de cuenta: correo electronico, nombre visible, nombre de usuario, fecha de nacimiento y foto de perfil opcional.
    2.2. Datos de contenido: fotos, videos, mensajes, comentarios y reacciones.
    2.3. Datos tecnicos: informacion del dispositivo, tokenes de notificacion, registros de errores y uso basico del servicio.
    2.4. Datos de ubicacion opcionales: coordenadas o ciudad cuando nos das permiso.

    3. BASES JURIDICAS Y FINALIDADES (Articulo 6 RGPD)

    3.1. Ejecucion del contrato (art. 6.1.b): crear y proteger tu cuenta, entregar fotos, videos, chats, rachas y notificaciones del servicio.
    3.2. Interes legitimo (art. 6.1.f): moderar contenido, prevenir abuso o fraude, y mejorar la estabilidad del producto.
    3.3. Obligacion legal (art. 6.1.c): cumplir obligaciones legales y requerimientos de autoridades competentes.
    3.4. Consentimiento (art. 6.1.a): recogida de datos de ubicacion y comunicaciones opcionales. Puedes retirar tu consentimiento en cualquier momento sin que ello afecte a la licitud del tratamiento previo.

    4. CON QUIEN COMPARTIMOS LOS DATOS

    4.1. Usamos Google Firebase (Google LLC, EE.UU.) para infraestructura, autenticacion, base de datos y almacenamiento. Las transferencias internacionales se amparan en las clausulas contractuales tipo aprobadas por la Comision Europea.
    4.2. Usamos servicios de Apple y Google para notificaciones push.
    4.3. Usamos herramientas automaticas de moderacion para detectar contenido inseguro.
    4.4. No vendemos tus datos ni los compartimos para publicidad de terceros.

    5. TIEMPOS DE CONSERVACION

    5.1. Las fotos compartidas se eliminan automaticamente tras 30 dias.
    5.2. Los datos de cuenta se mantienen mientras la cuenta siga activa.
    5.3. Cuando borras tu cuenta, iniciamos la eliminacion permanente de los datos del producto. Los datos pueden conservarse durante periodos adicionales si existe una obligacion legal.

    6. TUS DERECHOS (Articulos 15 a 22 RGPD)

    Tienes derecho a acceso, rectificacion, supresion ("derecho al olvido"), limitacion del tratamiento, portabilidad y oposicion. Puedes ejercer estos derechos escribiendo a info@celalbasaran.com con el asunto "Proteccion de Datos".

    7. AUTORIDAD DE CONTROL

    Si consideras que el tratamiento de tus datos no es conforme a la normativa, puedes presentar una reclamacion ante la Agencia Espanola de Proteccion de Datos (AEPD) en www.aepd.es.

    8. MENORES

    anlik. no esta disponible para menores de 16 anos. Si detectamos una cuenta por debajo de esa edad minima, podremos retirarla.

    9. SEGURIDAD

    Protegemos los datos con controles de acceso, cifrado en transito y reglas de seguridad en la infraestructura.

    10. CAMBIOS

    Si cambiamos esta politica, te lo notificaremos desde la app cuando corresponda.

    Contacto: info@celalbasaran.com
    """

    static let kvkkTextES = """
    ANLIK. AVISO DE PROTECCION DE DATOS (RGPD)
    Ultima actualizacion: 13 de marzo de 2026
    Version: 1.1.0

    Este documento informa sobre el tratamiento de datos personales conforme al Reglamento General de Proteccion de Datos (RGPD - Reglamento UE 2016/679) y la Ley Organica 3/2018 de Proteccion de Datos Personales y garantia de los derechos digitales (LOPDGDD).

    1. RESPONSABLE DEL TRATAMIENTO

    Celal Basaran (desarrollador independiente)
    Correo electronico: info@celalbasaran.com
    El responsable determina los fines y medios del tratamiento de tus datos personales.

    2. DATOS TRATADOS

    Nombre, nombre de usuario, correo electronico, fecha de nacimiento, contenido compartido (fotos, videos, mensajes), datos tecnicos (dispositivo, tokenes de notificacion, registros de errores) y, cuando das permiso, ubicacion.

    3. BASES JURIDICAS DEL TRATAMIENTO (Articulo 6 RGPD)

    3.1. Ejecucion del contrato (art. 6.1.b): creacion de cuenta, prestacion del servicio, entrega de contenido y notificaciones.
    3.2. Interes legitimo (art. 6.1.f): seguridad, moderacion de contenido, prevencion de fraude y mejora del servicio.
    3.3. Obligacion legal (art. 6.1.c): cumplimiento de requerimientos legales o judiciales.
    3.4. Consentimiento (art. 6.1.a): recogida de ubicacion y envio de comunicaciones opcionales. Puedes retirar tu consentimiento en cualquier momento.

    4. DESTINATARIOS Y TRANSFERENCIAS INTERNACIONALES

    4.1. Usamos Google Firebase (Google LLC, EE.UU.) para infraestructura, autenticacion, base de datos y almacenamiento. Las transferencias a EE.UU. se amparan en las clausulas contractuales tipo de la Comision Europea.
    4.2. Usamos servicios de Apple y Google para notificaciones push.
    4.3. Usamos herramientas automaticas de moderacion para detectar contenido inseguro.
    4.4. No vendemos tus datos ni los compartimos para publicidad de terceros.

    5. PLAZOS DE CONSERVACION

    5.1. Las fotos compartidas se eliminan automaticamente tras 30 dias.
    5.2. Los datos de cuenta se mantienen mientras la cuenta siga activa.
    5.3. Cuando borras tu cuenta, iniciamos la eliminacion permanente de los datos. Los datos pueden conservarse durante periodos adicionales si existe una obligacion legal.

    6. TUS DERECHOS (Articulos 15 a 22 RGPD)

    Tienes derecho a:
    - Acceso: conocer que datos tratamos sobre ti.
    - Rectificacion: corregir datos inexactos o incompletos.
    - Supresion ("derecho al olvido"): solicitar la eliminacion de tus datos.
    - Limitacion: restringir el tratamiento en determinadas circunstancias.
    - Portabilidad: recibir tus datos en un formato estructurado y de uso comun.
    - Oposicion: oponerte al tratamiento basado en interes legitimo.

    Para ejercer estos derechos, escribe a info@celalbasaran.com con el asunto "Proteccion de Datos".

    7. AUTORIDAD DE CONTROL

    Si consideras que el tratamiento de tus datos no es conforme a la normativa, puedes presentar una reclamacion ante la Agencia Espanola de Proteccion de Datos (AEPD) en www.aepd.es.

    8. MENORES

    anlik. no esta disponible para menores de 16 anos. Si detectamos una cuenta por debajo de esa edad minima, podremos retirarla.
    """

    static let eulaTextES = """
    ANLIK. ACUERDO DE LICENCIA (EULA)
    Ultima actualizacion: 13 de marzo de 2026
    Version: 1.1.0

    1. LICENCIA

    Te concedemos una licencia limitada, revocable, no exclusiva e intransferible para usar anlik. con fines personales y no comerciales.

    2. RESTRICCIONES

    No puedes copiar, revender, descompilar, modificar, alquilar ni intentar desactivar las protecciones de la app.

    3. PROPIEDAD INTELECTUAL

    El producto, la marca y sus componentes siguen perteneciendo a su titular. El contenido que compartes sigue siendo tuyo, sujeto a la licencia operativa necesaria para prestar el servicio.

    4. CONTENIDO GENERADO POR USUARIOS

    Podemos revisar, ocultar o eliminar contenido que incumpla las normas de comunidad o la ley. Tambien podemos suspender cuentas que incumplan repetidamente.

    5. RESPONSABILIDAD

    La app se distribuye sin garantias adicionales y, en la medida permitida por la ley, no asumimos responsabilidad por danos indirectos o derivados.

    6. FINALIZACION

    Podemos suspender o terminar el acceso si incumples estas condiciones. Tu tambien puedes dejar de usar la app y borrar tu cuenta en cualquier momento.

    7. CONTACTO

    info@celalbasaran.com
    """
}
