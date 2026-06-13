import XCTest
@testable import SoulmateCoffee

/// Excel formüllerinin uygulamada birebir karşılandığını doğrulayan testler.
final class CalculationTests: XCTestCase {

    private func makeItem(price: Double = 100) -> StockItem {
        StockItem(name: "Test", group: .sicakIcecek, unit: "KG", unitPrice: price)
    }

    // MARK: - StockItem

    func testAySonuStokUsesLastFilledCount() {
        var item = makeItem()
        item.sayim1 = 10
        item.sayim2 = 8
        XCTAssertEqual(item.aySonuStok, 8)
        item.sayim4 = 5
        XCTAssertEqual(item.aySonuStok, 5)
    }

    func testAySonuStokNilWhenNoCounts() {
        let item = makeItem()
        XCTAssertNil(item.aySonuStok)
    }

    func testToplamKullanimRequiresAllInputs() {
        var item = makeItem()
        item.devir = 20
        item.gelen = 30
        // sayım yok → 0
        XCTAssertEqual(item.toplamKullanim, 0)
        item.sayim1 = 15           // aySonuStok = 15
        XCTAssertEqual(item.toplamKullanim, 20 + 30 - 15)
    }

    func testKullanimTutari() {
        var item = makeItem(price: 50)
        item.devir = 10; item.gelen = 10; item.sayim1 = 5  // kullanım = 15
        XCTAssertEqual(item.kullanimTutari, 15 * 50)
    }

    func testZayiAndIkramTutari() {
        var item = makeItem(price: 20)
        item.zayiAdet = 3
        item.ikramAdet = 2
        XCTAssertEqual(item.zayiTutari, 60)
        XCTAssertEqual(item.ikramTutari, 40)
    }

    func testNetKullanim() {
        var item = makeItem(price: 10)
        item.devir = 100; item.gelen = 0; item.sayim1 = 40  // kullanım = 60
        item.zayiAdet = 5
        item.ikramAdet = 5
        XCTAssertEqual(item.netKullanimAdet, 50)
        XCTAssertEqual(item.netKullanimTutari, 500)
    }

    // MARK: - DailyTrackItem

    func testDailyTotal() {
        var item = DailyTrackItem(name: "ESPRESSO S")
        item.setCount(3, forDay: 1)
        item.setCount(2, forDay: 15)
        item.setCount(5, forDay: 31)
        XCTAssertEqual(item.total, 10)
        XCTAssertEqual(item.count(forDay: 15), 2)
    }

    func testDailyNormalizesTo31() {
        let item = DailyTrackItem(name: "X", counts: [1, 2, 3])
        XCTAssertEqual(item.counts.count, 31)
        XCTAssertEqual(item.total, 6)
    }

    func testDailyNeverNegative() {
        var item = DailyTrackItem(name: "X")
        item.setCount(-5, forDay: 1)
        XCTAssertEqual(item.count(forDay: 1), 0)
    }

    // MARK: - CostSummary

    func testCostSummaryAggregatesByGroup() {
        var data = SeedData.makePeriod(year: 2026, month: 1)
        // Tüm sıcak içecekleri temizleyip kontrollü iki ürün koyalım.
        var hot1 = StockItem(name: "A", group: .sicakIcecek, unit: "KG", unitPrice: 100)
        hot1.devir = 10; hot1.gelen = 0; hot1.sayim1 = 0   // kullanım 10 → 1000₺
        var sarf1 = StockItem(name: "B", group: .sarf, unit: "ADET", unitPrice: 50)
        sarf1.devir = 4; sarf1.gelen = 0; sarf1.sayim1 = 0  // kullanım 4 → 200₺
        data.stock = [hot1, sarf1]
        data.ciro = 2000
        data.calisanGunSayisi = 10

        let s = CostSummary(data)
        XCTAssertEqual(s.totalKullanim, 1200)
        XCTAssertEqual(s.costGenel, 1200.0 / 2000.0, accuracy: 0.0001)
        XCTAssertEqual(s.costSarf, 200.0 / 2000.0, accuracy: 0.0001)
        XCTAssertEqual(s.gunlukCiroOrt, 200, accuracy: 0.0001)
    }

    func testCostSummaryDivideByZeroSafe() {
        var data = SeedData.makePeriod(year: 2026, month: 1)
        data.ciro = 0
        data.calisanGunSayisi = 0
        let s = CostSummary(data)
        XCTAssertEqual(s.costGenel, 0)
        XCTAssertEqual(s.gunlukCiroOrt, 0)
        XCTAssertEqual(s.zayiCiroOrani, 0)
    }

    func testNetKazanc() {
        var data = SeedData.makePeriod(year: 2026, month: 1)
        data.stock = []         // COST malzeme = 0
        data.ciro = 10000
        data.personelMaliyet = 3000
        data.kira = 2000
        data.elektrik = 500
        data.su = 200
        data.dogalgaz = 300
        data.internet = 100
        data.digerGiderler = 400
        let s = CostSummary(data)
        XCTAssertEqual(s.giderToplam, 6500)
        XCTAssertEqual(s.netKazanc, 3500)
    }

    // MARK: - Seed

    func testSeedCatalogCounts() {
        let p = SeedData.makePeriod(year: 2026, month: 1)
        XCTAssertEqual(p.stock.count, 59)
        XCTAssertEqual(p.zayi.count, 182)
        XCTAssertEqual(p.ikram.count, 182)
    }

    func testDaysInMonth() {
        let feb = SeedData.makePeriod(year: 2026, month: 2)
        XCTAssertEqual(feb.daysInMonth, 28)
        let jan = SeedData.makePeriod(year: 2026, month: 1)
        XCTAssertEqual(jan.daysInMonth, 31)
    }
}
