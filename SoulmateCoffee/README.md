# Soulmate Coffee — Stok Takip (iOS)

**Soulmate Coffee - Kötekli Şubesi** için hazırlanmış stok, zayi, ikram ve
kâr/zarar takip uygulaması. Orijinal Excel tablosundan (`docs/soulmate_coffee_stok_takip.xlsx`)
birebir aktarılan iş mantığıyla, %100 SwiftUI ile yazılmıştır.

> Excel'deki 5 sayfa (STOK TAKİBİ, ZAYİ TAKİBİ, İKRAM TAKİBİ, COST-P&L, KULLANIM KILAVUZU)
> uygulamadaki 5 sekmeye karşılık gelir.

## Özellikler

- **Stok Takibi** — 59 ürünlük katalog (Sıcak/Soğuk İçecek, Gıda, Sarf, Temizlik).
  Devir, alım ve 4 sayım girişinden ay sonu stok, toplam kullanım, kullanım/zayi/ikram
  tutarları ve net kullanım **otomatik** hesaplanır (Excel formülleriyle birebir).
- **Zayi Takibi** — 182 menü kalemi için günlük (1–31) adet girişi ve aylık toplam.
- **İkram Takibi** — aynı yapıda günlük ikram takibi.
- **Kâr / Zarar (COST-P&L)** — ciro ve giderlerden cost oranları, ikram/zayi oranları,
  günlük ciro ortalaması ve **aylık net kazanç**. Kullanım dağılımı pasta grafiği.
- **Çoklu Dönem** — her ay için ayrı veri; üst menüden hızlı geçiş.
- **Kalıcı Depolama** — veriler cihazda JSON olarak otomatik kaydedilir.
- **CSV Dışa Aktarma**, Türkçe arayüz, ₺ biçimlendirme, açık/koyu tema.

## Gereksinimler

- Xcode 16+
- iOS 17.0+
- Swift 5

## Çalıştırma

```bash
open SoulmateCoffee.xcodeproj
```

Hedef cihaz/simülatör seçip **Run (⌘R)**. İmzalama için kendi Apple Developer
hesabınızı (Signing & Capabilities → Team) seçmeniz yeterlidir.

Testleri çalıştırmak için **⌘U** (hesaplama mantığını doğrulayan birim testleri).

### Projeyi yeniden üretme (opsiyonel)

`.xcodeproj` dosyası `project.yml` üzerinden [XcodeGen](https://github.com/yonebridge/XcodeGen)
ile yeniden üretilebilir:

```bash
brew install xcodegen
xcodegen generate
```

### Başlangıç verisini güncelleme

Excel güncellenirse katalog yeniden üretilebilir:

```bash
pip install openpyxl
python3 scripts/generate_seed.py docs/soulmate_coffee_stok_takip.xlsx
```

## Proje Yapısı

```
SoulmateCoffee/
├── SoulmateCoffeeApp.swift        # Uygulama girişi
├── Models/                        # StockItem, DailyTrackItem, Period, CostSummary
├── Store/                         # DataStore (kalıcılaştırma) + SeedData (katalog)
├── Views/                         # Stok / Daily (Zayi-İkram) / Summary / Settings
├── Utils/                         # Biçimlendiriciler (₺, %)
└── Resources/Assets.xcassets      # App ikonu + vurgu rengi
SoulmateCoffeeTests/               # Hesaplama birim testleri
```

## Hesaplama Mantığı (Excel ↔ Uygulama)

| Excel | Uygulama |
|-------|----------|
| `AY SONU STOK = IF(J;I;H;G)` | `StockItem.aySonuStok` (son dolu sayım) |
| `TOPLAM KULLANIM = Devir+Gelen−AySonu` | `StockItem.toplamKullanim` |
| `KULLANIM TUTARI = Kullanım×Fiyat` | `StockItem.kullanimTutari` |
| `NET KULLANIM = Kullanım−Zayi−İkram` | `StockItem.netKullanimAdet` |
| `GENEL COST % = Kullanım÷Ciro` | `CostSummary.costGenel` |
| `AYLIK NET KAZANÇ = Gelir−Gider` | `CostSummary.netKazanc` |

Tüm oranlar sıfıra bölme korumalıdır.
