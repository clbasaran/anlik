import Foundation

/// STOK TAKİBİ sayfasındaki tek bir ürün satırı.
///
/// Giriş alanları (Excel'de mavi hücreler) `Double?` olarak tutulur; `nil`
/// değer Excel'deki boş hücreye karşılık gelir. Hesaplanan sütunlar (formüller)
/// `computed property` olarak Excel formülleriyle birebir aynı mantıkta üretilir.
struct StockItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    // Sabit bilgiler
    var name: String
    var group: ProductGroup
    var unit: String          // KG / ADET / KOLİ
    var unitPrice: Double      // BİRİM FİYAT (KDV Hariç)

    // Giriş alanları (boş = nil)
    var devir: Double?         // E - DEVİR (Ay Başı)
    var gelen: Double?         // F - GELEN (Alım)
    var sayim1: Double?        // G - 1. SAYIM
    var sayim2: Double?        // H - 2. SAYIM
    var sayim3: Double?        // I - 3. SAYIM
    var sayim4: Double?        // J - 4. SAYIM
    var zayiAdet: Double?      // N - ZAYİ ADET
    var ikramAdet: Double?     // P - İKRAM ADET

    // MARK: - Hesaplanan alanlar (Excel formülleri)

    /// K — AY SONU STOK: =IF(J<>"",J,IF(I<>"",I,IF(H<>"",H,G)))
    /// En son doldurulan sayım değeri; hiçbiri yoksa nil.
    var aySonuStok: Double? {
        sayim4 ?? sayim3 ?? sayim2 ?? sayim1
    }

    /// L — TOPLAM KULLANIM: =IF(AND(E<>"",F<>"",K<>""),E+F-K,0)
    var toplamKullanim: Double {
        guard let e = devir, let f = gelen, let k = aySonuStok else { return 0 }
        return e + f - k
    }

    /// M — KULLANIM TUTARI (₺): =L*D
    var kullanimTutari: Double { toplamKullanim * unitPrice }

    /// O — ZAYİ TUTARI (₺): =IF(N="",0,N*D)
    var zayiTutari: Double { (zayiAdet ?? 0) * unitPrice }

    /// Q — İKRAM TUTARI (₺): =IF(P="",0,P*D)
    var ikramTutari: Double { (ikramAdet ?? 0) * unitPrice }

    /// R — NET KULLANIM ADET: =L - IF(N="",0,N) - IF(P="",0,P)
    var netKullanimAdet: Double {
        toplamKullanim - (zayiAdet ?? 0) - (ikramAdet ?? 0)
    }

    /// S — NET KULLANIM TUTARI (₺): =R*D
    var netKullanimTutari: Double { netKullanimAdet * unitPrice }

    /// Kullanıcının herhangi bir veri girip girmediği (liste görünümünde rozet için).
    var hasInput: Bool {
        devir != nil || gelen != nil || sayim1 != nil || sayim2 != nil ||
        sayim3 != nil || sayim4 != nil || zayiAdet != nil || ikramAdet != nil
    }
}
