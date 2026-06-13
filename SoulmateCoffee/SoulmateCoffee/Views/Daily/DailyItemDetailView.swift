import SwiftUI

/// Bir ürünün ayın tüm günlerine ait adetlerini gösteren/düzenleyen ekran.
struct DailyItemDetailView: View {
    @Binding var item: DailyTrackItem
    @EnvironmentObject private var store: DataStore

    private var days: Int { store.data.daysInMonth }

    var body: some View {
        List {
            Section {
                LabeledValueRow(label: "Aylık Toplam", value: "\(item.total)", emphasized: true)
            }
            Section("Günlük Adetler") {
                ForEach(1...days, id: \.self) { day in
                    Stepper(value: Binding(
                        get: { item.count(forDay: day) },
                        set: { item.setCount($0, forDay: day) }
                    ), in: 0...9999) {
                        HStack {
                            Text("\(day). gün")
                            Spacer()
                            Text("\(item.count(forDay: day))")
                                .monospacedDigit()
                                .foregroundStyle(item.count(forDay: day) > 0 ? .primary : .secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
