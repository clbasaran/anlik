import Foundation

/// Bir ay/yıl dönemine ait tüm veriler. Excel dosyasının tek bir aylık
/// kopyasının karşılığıdır (STOK + ZAYİ + İKRAM + COST/P&L girişleri).
struct AppData: Codable, Identifiable {
    var id: UUID = UUID()

    // Şube & dönem bilgileri
    var branchName: String
    var year: Int
    var month: Int            // 1...12

    // COST - P&L giriş alanları
    var ciro: Double                 // CİRO (₺)
    var calisanGunSayisi: Double     // ÇALIŞAN GÜN SAYISI
    var personelMaliyet: Double      // Personel Maliyet
    var kira: Double                 // Kira
    var elektrik: Double             // Elektrik
    var su: Double                   // Su
    var dogalgaz: Double             // Doğalgaz
    var internet: Double             // İnternet
    var digerGiderler: Double        // Diğer Giderler / Vergiler

    // Sayfa verileri
    var stock: [StockItem]
    var zayi: [DailyTrackItem]
    var ikram: [DailyTrackItem]

    var periodKey: String { AppData.key(year: year, month: month) }

    var monthName: String { AppData.monthNames[(month - 1 + 12) % 12] }

    var title: String { "\(monthName) \(year)" }

    /// Ayın gün sayısı (gün seçici için).
    var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar(identifier: .gregorian)
        if let date = cal.date(from: comps),
           let range = cal.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    func tracks(for kind: DailyTrackKind) -> [DailyTrackItem] {
        kind == .zayi ? zayi : ikram
    }

    static let monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ]

    static func key(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }
}
