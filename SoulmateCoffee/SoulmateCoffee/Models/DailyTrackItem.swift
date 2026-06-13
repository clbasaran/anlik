import Foundation

/// ZAYİ TAKİBİ ve İKRAM TAKİBİ sayfalarındaki günlük takip satırı.
///
/// Her ürün için ayın 1-31 günlerine ait adetler `counts` dizisinde tutulur
/// (index 0 = 1. gün). Excel'deki "TOPLAM" sütunu `total` ile hesaplanır.
struct DailyTrackItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// 31 elemanlı günlük adet dizisi (index 0 → ayın 1'i).
    var counts: [Int]

    init(id: UUID = UUID(), name: String, counts: [Int]? = nil) {
        self.id = id
        self.name = name
        self.counts = counts ?? Array(repeating: 0, count: 31)
        normalize()
    }

    /// Diziyi her zaman 31 elemana sabitler (eski/eksik veriler için güvenlik).
    mutating func normalize() {
        if counts.count < 31 {
            counts.append(contentsOf: Array(repeating: 0, count: 31 - counts.count))
        } else if counts.count > 31 {
            counts = Array(counts.prefix(31))
        }
    }

    /// TOPLAM — tüm günlerin toplamı.
    var total: Int { counts.reduce(0, +) }

    /// Belirli bir gün için adede güvenli erişim (day: 1...31).
    func count(forDay day: Int) -> Int {
        guard day >= 1, day <= counts.count else { return 0 }
        return counts[day - 1]
    }

    mutating func setCount(_ value: Int, forDay day: Int) {
        guard day >= 1, day <= counts.count else { return }
        counts[day - 1] = max(0, value)
    }
}

/// Günlük takip türü — ZAYİ veya İKRAM. Tek bir ekran her iki türü de besler.
enum DailyTrackKind: String, Codable, CaseIterable, Identifiable {
    case zayi
    case ikram

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zayi: return "Zayi Takibi"
        case .ikram: return "İkram Takibi"
        }
    }

    var systemImage: String {
        switch self {
        case .zayi: return "trash.fill"
        case .ikram: return "gift.fill"
        }
    }

    var description: String {
        switch self {
        case .zayi: return "Günlük zayi (bozulan/dökülen) ürün adetlerini girin."
        case .ikram: return "Günlük ikram edilen ürün adetlerini girin."
        }
    }
}
