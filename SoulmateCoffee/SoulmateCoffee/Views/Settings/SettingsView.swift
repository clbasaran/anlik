import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Şube") {
                    TextField("Şube Adı", text: $store.data.branchName, axis: .vertical)
                    LabeledValueRow(label: "Aktif Dönem", value: store.data.title)
                }

                Section("Dönemler") {
                    ForEach(store.allPeriods) { period in
                        HStack {
                            Button {
                                store.switchToPeriod(year: period.year, month: period.month)
                            } label: {
                                HStack {
                                    Text(period.title)
                                    if period.periodKey == store.data.periodKey {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.brown)
                                    }
                                }
                            }
                            .tint(.primary)
                            Spacer()
                        }
                    }
                    NavigationLink {
                        NewPeriodInlineView()
                    } label: {
                        Label("Yeni Dönem Oluştur", systemImage: "calendar.badge.plus")
                    }
                }

                Section("Veri") {
                    ShareLink(item: store.exportCSV(),
                              preview: SharePreview("\(store.data.title) - Stok Raporu")) {
                        Label("CSV Olarak Dışa Aktar", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    NavigationLink {
                        GuideView()
                    } label: {
                        Label("Kullanım Kılavuzu", systemImage: "book.fill")
                    }
                }

                Section("Tehlikeli Bölge") {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Aktif Dönemi Sil", systemImage: "trash")
                    }
                }

                Section {
                    LabeledValueRow(label: "Uygulama", value: "Soulmate Coffee Stok")
                    LabeledValueRow(label: "Sürüm", value: appVersion)
                }
            }
            .navigationTitle("Ayarlar")
            .confirmationDialog("Bu dönem silinsin mi?",
                                isPresented: $showingDeleteConfirm,
                                titleVisibility: .visible) {
                Button("\(store.data.title) dönemini sil", role: .destructive) {
                    store.deletePeriod(year: store.data.year, month: store.data.month)
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu döneme ait tüm stok, zayi ve ikram verileri silinecek.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Ayarlar içinden yeni dönem oluşturma (push navigasyon).
private struct NewPeriodInlineView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    private let years: [Int] = {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...(current + 1))
    }()

    var body: some View {
        Form {
            Picker("Yıl", selection: $year) {
                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
            }
            Picker("Ay", selection: $month) {
                ForEach(1...12, id: \.self) { Text(AppData.monthNames[$0 - 1]).tag($0) }
            }
            Button("Oluştur ve Geç") {
                store.createPeriod(year: year, month: month)
                dismiss()
            }
        }
        .navigationTitle("Yeni Dönem")
        .navigationBarTitleDisplayMode(.inline)
    }
}
