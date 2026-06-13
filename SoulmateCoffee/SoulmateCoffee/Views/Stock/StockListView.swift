import SwiftUI

/// STOK TAKİBİ — gruplara göre ürün listesi + aylık kullanım özeti.
struct StockListView: View {
    @EnvironmentObject private var store: DataStore
    @State private var searchText = ""
    @State private var showingAdd = false

    private var summary: CostSummary { CostSummary(store.data) }

    private func items(in group: ProductGroup) -> [StockItem] {
        store.data.stock.filter { item in
            item.group == group &&
            (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                ForEach(ProductGroup.allCases) { group in
                    let groupItems = items(in: group)
                    if !groupItems.isEmpty {
                        Section {
                            ForEach(groupItems) { item in
                                NavigationLink {
                                    editor(for: item)
                                } label: {
                                    StockRowView(item: item)
                                }
                            }
                            .onDelete { offsets in
                                deleteRespectingFilter(offsets, in: group, visible: groupItems)
                            }
                        } header: {
                            Label(group.displayName, systemImage: group.systemImage)
                                .foregroundStyle(group.tint)
                        }
                    }
                }
            }
            .navigationTitle("Stok Takibi")
            .searchable(text: $searchText, prompt: "Ürün ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PeriodMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddStockItemSheet().environmentObject(store)
            }
            .overlay {
                if store.data.stock.isEmpty {
                    EmptyStateView(title: "Ürün yok",
                                   message: "Sağ üstteki + ile ürün ekleyin.",
                                   systemImage: "cube.box")
                }
            }
        }
    }

    private var summaryHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(title: "Toplam Kullanım", value: Format.tl(summary.totalKullanim),
                         systemImage: "arrow.down.circle.fill", tint: .brown)
                StatCard(title: "Kalan Stok", value: Format.tl(summary.totalKalan),
                         systemImage: "shippingbox.fill", tint: .blue)
                StatCard(title: "Zayi", value: Format.tl(summary.zayiToplamTL),
                         systemImage: "trash.fill", tint: .red)
                StatCard(title: "İkram", value: Format.tl(summary.ikramToplamTL),
                         systemImage: "gift.fill", tint: .green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func editor(for item: StockItem) -> some View {
        if let index = store.data.stock.firstIndex(where: { $0.id == item.id }) {
            StockItemEditView(item: $store.data.stock[index])
        }
    }

    private func deleteRespectingFilter(_ offsets: IndexSet, in group: ProductGroup, visible: [StockItem]) {
        let ids = offsets.map { visible[$0].id }
        store.data.stock.removeAll { ids.contains($0.id) }
    }
}

struct StockRowView: View {
    let item: StockItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.unit)
                    Text("·")
                    Text(Format.tl(item.unitPrice))
                    if item.hasInput {
                        Text("·")
                        Text("Kullanım: \(Format.number(item.toplamKullanim))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.hasInput {
                Text(Format.tl(item.kullanimTutari))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.brown)
            }
        }
    }
}
