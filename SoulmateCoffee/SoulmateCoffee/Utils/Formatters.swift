import Foundation

/// Uygulama genelinde kullanılan biçimlendiriciler (Türkçe / ₺).
enum Format {
    private static let locale = Locale(identifier: "tr_TR")

    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        f.currencyCode = "TRY"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    static let percent: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.locale = locale
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    static func tl(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? "₺0"
    }

    static func number(_ value: Double) -> String {
        decimal.string(from: NSNumber(value: value)) ?? "0"
    }

    static func pct(_ ratio: Double) -> String {
        percent.string(from: NSNumber(value: ratio)) ?? "%0"
    }
}
