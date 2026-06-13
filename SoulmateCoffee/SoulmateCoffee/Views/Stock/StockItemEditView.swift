import SwiftUI

/// Tek bir stok ürününün aylık giriş alanlarını düzenleme ekranı.
/// Hesaplanan alanlar (AY SONU STOK, KULLANIM, NET KULLANIM...) anlık gösterilir.
struct StockItemEditView: View {
    @Binding var item: StockItem

    var body: some View {
        Form {
            Section("Ürün") {
                LabeledValueRow(label: "Grup", value: item.group.displayName)
                LabeledValueRow(label: "Birim", value: item.unit)
                DecimalField(title: "Birim Fiyat (KDV Hariç)", value: $item.unitPrice, suffix: "₺")
            }

            Section("Stok Girişi") {
                OptionalDecimalField(title: "Devir (Ay Başı)", value: $item.devir)
                OptionalDecimalField(title: "Gelen (Alım)", value: $item.gelen)
            }

            Section("Sayımlar") {
                OptionalDecimalField(title: "1. Sayım", value: $item.sayim1)
                OptionalDecimalField(title: "2. Sayım", value: $item.sayim2)
                OptionalDecimalField(title: "3. Sayım", value: $item.sayim3)
                OptionalDecimalField(title: "4. Sayım", value: $item.sayim4)
            }

            Section("Zayi & İkram") {
                OptionalDecimalField(title: "Zayi Adet", value: $item.zayiAdet)
                OptionalDecimalField(title: "İkram Adet", value: $item.ikramAdet)
            }

            Section("Hesaplanan") {
                LabeledValueRow(label: "Ay Sonu Stok",
                                value: item.aySonuStok.map(Format.number) ?? "—")
                LabeledValueRow(label: "Toplam Kullanım",
                                value: Format.number(item.toplamKullanim))
                LabeledValueRow(label: "Kullanım Tutarı",
                                value: Format.tl(item.kullanimTutari), emphasized: true)
                LabeledValueRow(label: "Zayi Tutarı",
                                value: Format.tl(item.zayiTutari), valueColor: .red)
                LabeledValueRow(label: "İkram Tutarı",
                                value: Format.tl(item.ikramTutari), valueColor: .green)
                LabeledValueRow(label: "Net Kullanım Adet",
                                value: Format.number(item.netKullanimAdet))
                LabeledValueRow(label: "Net Kullanım Tutarı",
                                value: Format.tl(item.netKullanimTutari), emphasized: true)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Yeni stok ürünü ekleme ekranı.
struct AddStockItemSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var group: ProductGroup = .sicakIcecek
    @State private var unit = "ADET"
    @State private var unitPrice: Double = 0

    private let units = ["ADET", "KG", "KOLİ", "LT", "PAKET"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Ürün Bilgileri") {
                    TextField("Ürün adı", text: $name)
                    Picker("Grup", selection: $group) {
                        ForEach(ProductGroup.allCases) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    DecimalField(title: "Birim Fiyat", value: $unitPrice, suffix: "₺")
                }
            }
            .navigationTitle("Yeni Ürün")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.addStockItem(StockItem(name: trimmed, group: group,
                                                     unit: unit, unitPrice: unitPrice))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
