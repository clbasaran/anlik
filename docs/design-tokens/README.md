# anlık. Design Tokens

W3C [Design Tokens Community Group (DTCG)](https://www.designtokens.org/) format. Tek dosya: [`anlik.tokens.json`](./anlik.tokens.json). 1.0.0.

Bu klasör **Brand.swift** ve **WatchBrand.swift**'ten türetildi. Değişiklik akış yönü:

```
Figma (Tokens Studio) ──┐
                        ├──> anlik.tokens.json  ──> Brand.swift / WatchBrand.swift
Kod (manuel düzeltme) ──┘                            (Style Dictionary ile veya elle)
```

JSON **kanonik kaynak** — Brand.swift ona uymak zorunda. Yeni token eklemek istersen önce JSON'a ekle, sonra Swift tarafa propage et.

---

## Yapı

```
core/         primitives — siyah, beyaz, opacity'ler, weight'ler, duration'lar
semantic/     aliased — text.primary, surface.default, feedback.error
platform/
  ios/        iOS scale (spacing/radius/typography)
  watch/      watchOS scale (tighter — 38–49mm)
motion/       spring presets (snap, standard, soft, fade)
component/    composite recipes (card, button, syncIndicator)
voice/        copy & icon kuralları (token-as-documentation)
```

**Asla `core.*` referansını doğrudan view'da kullanma.** Her zaman `semantic.*` veya `component.*` üzerinden geç. iOS/Watch scale farkını da `platform.ios.*` vs `platform.watch.*` ile yönet.

---

## Figma'da kullanım (Tokens Studio)

[Tokens Studio for Figma](https://tokens.studio/) plugin'i:

1. Figma → Plugins → **Tokens Studio for Figma** aç
2. **Sync** sekmesi → **GitHub** (veya local JSON)
3. URL: bu repo / file path: `docs/design-tokens/anlik.tokens.json`
4. **Pull** → tüm tokenlar Figma'ya yüklenir, **Color**/**Typography**/**Spacing** kategorilerine düşer
5. Figma'da renkleri/spacing'i Style olarak uygula → tasarımın tokenize olur
6. Yeni token gerekirse Tokens Studio'da ekle → **Push to GitHub** → PR aç → kod tarafına propage et

**Tema variants** (ileride iOS/Watch için ayrı tema gerekirse): Tokens Studio "Themes" özelliği `platform.ios` ve `platform.watch` set'lerini farklı tema olarak yönetir.

---

## Style Dictionary ile platform output üretmek

`anlik.tokens.json` → Swift / CSS / Android XML output:

```bash
# Bir kez kur
npm init -y
npm install --save-dev style-dictionary@4

# Config (config.json)
cat > sd.config.json << 'EOF'
{
  "source": ["docs/design-tokens/anlik.tokens.json"],
  "platforms": {
    "swift-ios": {
      "transformGroup": "ios-swift",
      "buildPath": "build/ios/",
      "files": [{
        "destination": "BrandGenerated.swift",
        "format": "ios-swift/class.swift",
        "className": "BrandGenerated"
      }]
    },
    "swift-watch": {
      "transformGroup": "ios-swift",
      "buildPath": "build/watch/",
      "files": [{
        "destination": "WatchBrandGenerated.swift",
        "format": "ios-swift/class.swift",
        "className": "WatchBrandGenerated"
      }]
    },
    "css": {
      "transformGroup": "css",
      "buildPath": "build/css/",
      "files": [{ "destination": "tokens.css", "format": "css/variables" }]
    }
  }
}
EOF

# Build
npx style-dictionary build --config sd.config.json
```

Çıktıda:
- `build/ios/BrandGenerated.swift` — iOS Brand class (rename/karşılaştırarak Brand.swift'e merge et)
- `build/css/tokens.css` — web landing page (`public/`) için CSS variables

---

## Specify / Supernova / diğer araçlar

DTCG standart format olduğu için:
- **[Specify](https://specifyapp.com/)** — `Import → JSON Tokens` ile direkt yükle
- **[Supernova](https://www.supernova.io/)** — `Sources → Tokens → DTCG JSON`
- **[Knapsack](https://knapsack.cloud/)** — design system manager
- **[Penpot](https://penpot.app/)** (open source Figma alternatifi) — tokens API'siyle

---

## Hangi token nerede karşılığı bulur (Swift ↔ JSON)

| Swift | JSON path |
|---|---|
| `Brand.black` | `core.color.black` |
| `Brand.textPrimary` | `semantic.color.text.primary` |
| `Brand.textSecondary` | `semantic.color.text.secondary-ios` |
| `Brand.darkGray` | `semantic.color.surface.default` |
| `Brand.Spacing.md` | `platform.ios.spacing.md` |
| `Brand.Radius.md` | `platform.ios.radius.md` |
| `Brand.headline()` | `platform.ios.typography.headline` |
| `Brand.Animations.snap` | `motion.snap` |
| `WatchBrand.textSecondary` | `semantic.color.text.secondary-watch` |
| `WatchBrand.Spacing.md` | `platform.watch.spacing.md` |
| `WatchBrand.headline()` | `platform.watch.typography.headline` |
| `WatchBrand.success` | `semantic.color.feedback.success` |
| `WatchBrand.error` | `semantic.color.feedback.error` |
| `WatchBrand.name` | `voice.name` |

---

## DTCG'nin ifade edemediği şeyler (manuel sync gerekenler)

1. **SwiftUI spring physics** — DTCG `transition` tipi sadece duration + easing tutuyor; `response`/`dampingFraction` özel olarak `motion.*` altında string olarak duruyor. Style Dictionary tarafında custom transform yazılarak `Animation.spring(response:dampingFraction:)`'a map edilebilir.
2. **`Font.system(.rounded)` design parameter** — DTCG fontFamily tek string; rounded design ayrı. `platform.watch.typography.stat` için tokenları çekerken Swift kod tarafında `Font.system(size:, weight:, design: .rounded)` el ile yazılmalı.
3. **Material / blur backgrounds** — DTCG'de yok. Mevcut tasarımda kullanılmıyor (pure monochrome), gelecekte gerekirse `component.surface.glassmorphic` gibi custom token tipi tanımlanabilir.

---

## Brand voice tokenları (`voice.*`)

DTCG'de **non-visual rules**'ı token olarak ifade etmek alışılmadık ama biz kullanıyoruz çünkü:

- `voice.name = "anlık."` — PR review'da yanlış adı yakalamak için linter rule
- `voice.iconLibrary = "SF Symbols only."` — emoji ihlali yakalama
- `voice.tone` — copy yazılırken çıkartılan referans

Bunlar Figma'da gözükmez ama dökümantasyon olarak kalır, Style Dictionary'de `.txt` output formatı ile codebase'e markdown olarak da export edilebilir.

---

## Değişiklik politikası

1. Yeni token eklenecek mi? → Önce JSON'a ekle, sonra Brand.swift/WatchBrand.swift'e propage et
2. Mevcut tokenın değeri değişecek mi? → JSON'da değiştir, **sürüm bump** (`$metadata.version`), Brand.swift'e propage et
3. Token silinecek mi? → Önce 1 sürüm `$deprecated: true` ekle, sonra sil

---

## Kalite kontrol

```bash
# JSON geçerli mi?
python3 -m json.tool docs/design-tokens/anlik.tokens.json > /dev/null && echo OK

# Token Studio schema'ya uygun mu?
npx -p tokens-studio-schema validate docs/design-tokens/anlik.tokens.json

# Style Dictionary build edebiliyor mu?
npx style-dictionary build --config sd.config.json
```

---

## Sürüm

`1.0.0` — ilk çıkarış (2026-05-22). Brand.swift v0 (yıl-Mart) + WatchBrand.swift v1 (yıl-Mayıs) snapshot'ı.
