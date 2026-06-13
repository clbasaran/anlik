import SwiftUI

/// Stok ürün grupları. Excel'deki "GRUP" sütununun birebir karşılığıdır.
enum ProductGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case sicakIcecek = "SICAK İÇECEK"
    case sogukIcecek = "SOĞUK İÇECEK"
    case gida = "GIDA"
    case sarf = "SARF"
    case temizlik = "TEMİZLİK"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .sicakIcecek: return "cup.and.saucer.fill"
        case .sogukIcecek: return "waterbottle.fill"
        case .gida: return "fork.knife"
        case .sarf: return "shippingbox.fill"
        case .temizlik: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .sicakIcecek: return .brown
        case .sogukIcecek: return .blue
        case .gida: return .orange
        case .sarf: return .purple
        case .temizlik: return .teal
        }
    }
}
