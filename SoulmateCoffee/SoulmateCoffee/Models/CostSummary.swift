import Foundation

/// COST - P&L sayfasının hesaplama motoru. Tüm değerler `AppData`dan türetilir
/// ve Excel formülleriyle birebir aynıdır.
struct CostSummary {
    let data: AppData

    init(_ data: AppData) { self.data = data }

    // MARK: - Kategori bazlı toplu veriler (TOPLU VERİLER tablosu)

    struct CategoryAggregate: Identifiable {
        let group: ProductGroup
        let devirTL: Double    // B - DEVİR (₺)  = Σ devir * fiyat
        let gelenTL: Double    // C - GELEN (₺)  = Σ gelen * fiyat
        let kalanTL: Double    // D - KALAN (₺)  = Σ aySonuStok * fiyat
        let kullanimTL: Double // E - KULLANIM (₺) = Σ kullanımTutarı
        var id: String { group.id }
    }

    var categories: [CategoryAggregate] {
        ProductGroup.allCases.map { group in
            let items = data.stock.filter { $0.group == group }
            return CategoryAggregate(
                group: group,
                devirTL: items.reduce(0) { $0 + ($1.devir ?? 0) * $1.unitPrice },
                gelenTL: items.reduce(0) { $0 + ($1.gelen ?? 0) * $1.unitPrice },
                kalanTL: items.reduce(0) { $0 + ($1.aySonuStok ?? 0) * $1.unitPrice },
                kullanimTL: items.reduce(0) { $0 + $1.kullanimTutari }
            )
        }
    }

    private func kullanim(_ group: ProductGroup) -> Double {
        categories.first { $0.group == group }?.kullanimTL ?? 0
    }

    var totalDevir: Double { categories.reduce(0) { $0 + $1.devirTL } }
    var totalGelen: Double { categories.reduce(0) { $0 + $1.gelenTL } }
    var totalKalan: Double { categories.reduce(0) { $0 + $1.kalanTL } }
    var totalKullanim: Double { categories.reduce(0) { $0 + $1.kullanimTL } }

    // MARK: - Stok kaynaklı toplamlar

    var zayiToplamTL: Double { data.stock.reduce(0) { $0 + $1.zayiTutari } }   // STOK!O63
    var ikramToplamTL: Double { data.stock.reduce(0) { $0 + $1.ikramTutari } } // STOK!Q63

    var ciro: Double { data.ciro }

    // MARK: - Şube bilgileri / oranlar (sıfıra bölme korumalı)

    private func ratio(_ numerator: Double, _ denominator: Double) -> Double {
        denominator == 0 ? 0 : numerator / denominator
    }

    var ikramCiroOrani: Double { ratio(ikramToplamTL, ciro) }   // H7
    var zayiCiroOrani: Double { ratio(zayiToplamTL, ciro) }     // H8
    var gunlukCiroOrt: Double { ratio(ciro, data.calisanGunSayisi) } // H9

    // COST ORANLARI
    var costGida: Double {  // H13 = (E_sıcak + E_soğuk + E_gıda) / ciro
        ratio(kullanim(.sicakIcecek) + kullanim(.sogukIcecek) + kullanim(.gida), ciro)
    }
    var costSarf: Double { ratio(kullanim(.sarf), ciro) }            // H14
    var costTemizlik: Double { ratio(kullanim(.temizlik), ciro) }    // H15
    var costGenel: Double { ratio(totalKullanim, ciro) }            // H16

    // MARK: - GELİR / GİDER TABLOSU

    var gunlukOrtalama: Double { gunlukCiroOrt }            // B16
    var costMalzeme: Double { totalKullanim }              // B18 = E10

    var gelirToplam: Double { ciro }                       // B26 = B15

    /// B27 = SUM(Personel, COST(Malzeme), Kira, Elektrik, Su, Doğalgaz, İnternet, Diğer)
    var giderToplam: Double {
        data.personelMaliyet + costMalzeme + data.kira + data.elektrik +
        data.su + data.dogalgaz + data.internet + data.digerGiderler
    }

    var netKazanc: Double { gelirToplam - giderToplam }   // B28
}
