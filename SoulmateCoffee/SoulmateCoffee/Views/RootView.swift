import SwiftUI

/// Ana sekme yapısı. Excel'deki 5 sayfanın karşılığı:
/// Stok / Zayi / İkram / Özet (Cost-P&L) / Ayarlar (Kullanım Kılavuzu dahil).
struct RootView: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        TabView {
            StockListView()
                .tabItem { Label("Stok", systemImage: "cube.box.fill") }

            DailyTrackView(kind: .zayi)
                .tabItem { Label("Zayi", systemImage: DailyTrackKind.zayi.systemImage) }

            DailyTrackView(kind: .ikram)
                .tabItem { Label("İkram", systemImage: DailyTrackKind.ikram.systemImage) }

            SummaryView()
                .tabItem { Label("Özet", systemImage: "chart.pie.fill") }

            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView().environmentObject(DataStore())
}
