import SwiftUI

/// Özet kartlarında kullanılan istatistik kutusu.
struct StatCard: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .brown

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Etiket + değer satırı (Özet listeleri için).
struct LabeledValueRow: View {
    let label: String
    let value: String
    var emphasized: Bool = false
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(emphasized ? .semibold : .regular)
            Spacer()
            Text(value)
                .fontWeight(emphasized ? .bold : .regular)
                .foregroundStyle(valueColor ?? .primary)
        }
    }
}

/// Boş durum görünümü.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

/// Dönem seçici / oluşturucu menüsü (araç çubuğu).
struct PeriodMenu: View {
    @EnvironmentObject private var store: DataStore
    @State private var showingNew = false

    var body: some View {
        Menu {
            ForEach(store.allPeriods) { period in
                Button {
                    store.switchToPeriod(year: period.year, month: period.month)
                } label: {
                    if period.periodKey == store.data.periodKey {
                        Label(period.title, systemImage: "checkmark")
                    } else {
                        Text(period.title)
                    }
                }
            }
            Divider()
            Button {
                showingNew = true
            } label: {
                Label("Yeni Dönem", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.data.title).fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
        }
        .sheet(isPresented: $showingNew) {
            NewPeriodSheet().environmentObject(store)
        }
    }
}

/// Yeni dönem oluşturma ekranı.
struct NewPeriodSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    private let years: [Int] = {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...(current + 1))
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Dönem") {
                    Picker("Yıl", selection: $year) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    Picker("Ay", selection: $month) {
                        ForEach(1...12, id: \.self) { m in
                            Text(AppData.monthNames[m - 1]).tag(m)
                        }
                    }
                }
                Section {
                    Text("Yeni dönem, ürün kataloğuyla birlikte boş olarak oluşturulur.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Yeni Dönem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        store.createPeriod(year: year, month: month)
                        dismiss()
                    }
                }
            }
        }
    }
}
