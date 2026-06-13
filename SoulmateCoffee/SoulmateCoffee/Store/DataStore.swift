import Foundation
import Combine

/// Tüm dönemlerin verisini tutan ve diske (JSON) kalıcılaştıran ana depo.
///
/// Aktif dönem `data` üzerinden okunur/yazılır; diğer dönemler `archive`
/// içinde saklanır. Değişiklikler kısa bir gecikmeyle (debounce) otomatik
/// olarak `Documents/soulmate_data.json` dosyasına yazılır.
final class DataStore: ObservableObject {

    /// Aktif dönem verisi. SwiftUI binding'leri doğrudan bunun üzerinde çalışır.
    @Published var data: AppData {
        didSet { scheduleSave() }
    }

    /// Geçmiş/diğer dönemler (aktif dönem hariç). Kayıt sırasında birleştirilir.
    private var archive: [String: AppData]

    private var saveWork: DispatchWorkItem?

    private static let fileName = "soulmate_data.json"

    // MARK: - Persisted dosya formatı

    private struct Persisted: Codable {
        var currentKey: String
        var periods: [String: AppData]
    }

    // MARK: - Init

    init() {
        if let loaded = DataStore.load() {
            archive = loaded.periods
            let current = loaded.periods[loaded.currentKey] ?? loaded.periods.values.first
            data = current ?? DataStore.defaultPeriod()
            archive.removeValue(forKey: data.periodKey)
        } else {
            let seed = DataStore.defaultPeriod()
            data = seed
            archive = [:]
        }
    }

    private static func defaultPeriod() -> AppData {
        // Excel dosyasının dönemi: 2026 Ocak
        SeedData.makePeriod(year: 2026, month: 1)
    }

    // MARK: - Dönem yönetimi

    /// Mevcut (aktif + arşiv) tüm dönemler, yeniden eskiye sıralı.
    var allPeriods: [AppData] {
        var dict = archive
        dict[data.periodKey] = data
        return dict.values.sorted {
            ($0.year, $0.month) > ($1.year, $1.month)
        }
    }

    func switchToPeriod(year: Int, month: Int) {
        let targetKey = AppData.key(year: year, month: month)
        guard targetKey != data.periodKey else { return }
        // Aktif dönemi arşive al.
        archive[data.periodKey] = data
        if let existing = archive[targetKey] {
            data = existing
            archive.removeValue(forKey: targetKey)
        } else {
            data = SeedData.makePeriod(year: year, month: month)
        }
        persistNow()
    }

    func createPeriod(year: Int, month: Int) {
        let key = AppData.key(year: year, month: month)
        if key == data.periodKey || archive[key] != nil {
            switchToPeriod(year: year, month: month)
            return
        }
        archive[data.periodKey] = data
        data = SeedData.makePeriod(year: year, month: month)
        persistNow()
    }

    func deletePeriod(year: Int, month: Int) {
        let key = AppData.key(year: year, month: month)
        if key == data.periodKey {
            // Aktif dönemi silmek için başka bir döneme geç ya da yeniden tohumla.
            if let other = archive.values.sorted(by: { ($0.year,$0.month) > ($1.year,$1.month) }).first {
                data = other
                archive.removeValue(forKey: other.periodKey)
            } else {
                data = DataStore.defaultPeriod()
            }
        } else {
            archive.removeValue(forKey: key)
        }
        persistNow()
    }

    // MARK: - Stok işlemleri

    func addStockItem(_ item: StockItem) {
        data.stock.append(item)
    }

    func deleteStockItems(at offsets: IndexSet, in group: ProductGroup) {
        let ids = data.stock.enumerated()
            .filter { $0.element.group == group }
            .map { $0.element.id }
        let toRemove = offsets.map { ids[$0] }
        data.stock.removeAll { toRemove.contains($0.id) }
    }

    // MARK: - Dışa aktarma (CSV)

    func exportCSV() -> String {
        var rows: [String] = []
        func esc(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        rows.append("# \(data.branchName) - \(data.title)")
        rows.append("")
        rows.append("## STOK TAKİBİ")
        rows.append(["ÜRÜN","GRUP","BİRİM","BİRİM FİYAT","DEVİR","GELEN","AY SONU STOK","TOPLAM KULLANIM","KULLANIM TUTARI","ZAYİ ADET","İKRAM ADET","NET KULLANIM","NET KULLANIM TUTARI"].map(esc).joined(separator: ","))
        for s in data.stock {
            rows.append([
                esc(s.name), esc(s.group.rawValue), esc(s.unit),
                Format.number(s.unitPrice),
                s.devir.map(Format.number) ?? "",
                s.gelen.map(Format.number) ?? "",
                s.aySonuStok.map(Format.number) ?? "",
                Format.number(s.toplamKullanim),
                Format.number(s.kullanimTutari),
                s.zayiAdet.map(Format.number) ?? "",
                s.ikramAdet.map(Format.number) ?? "",
                Format.number(s.netKullanimAdet),
                Format.number(s.netKullanimTutari)
            ].joined(separator: ","))
        }
        rows.append("")
        let summary = CostSummary(data)
        rows.append("## COST - P&L")
        rows.append("KALEM,TUTAR")
        rows.append("Ciro,\(Format.number(summary.ciro))")
        rows.append("COST (Malzeme),\(Format.number(summary.costMalzeme))")
        rows.append("Gider Toplam,\(Format.number(summary.giderToplam))")
        rows.append("Net Kazanç,\(Format.number(summary.netKazanc))")
        return rows.joined(separator: "\n")
    }

    // MARK: - Kalıcılaştırma

    private static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private static func load() -> Persisted? {
        let url = fileURL()
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Persisted.self, from: raw)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persistNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func persistNow() {
        saveWork?.cancel()
        var periods = archive
        periods[data.periodKey] = data
        let payload = Persisted(currentKey: data.periodKey, periods: periods)
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        try? encoded.write(to: DataStore.fileURL(), options: [.atomic])
    }
}
