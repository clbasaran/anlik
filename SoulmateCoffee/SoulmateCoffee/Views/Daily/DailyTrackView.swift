import SwiftUI

/// ZAYİ TAKİBİ / İKRAM TAKİBİ — gün seçilir, ürünlere o güne ait adet girilir.
struct DailyTrackView: View {
    let kind: DailyTrackKind
    @EnvironmentObject private var store: DataStore

    @State private var selectedDay: Int = min(Calendar.current.component(.day, from: Date()), 31)
    @State private var searchText = ""

    private var itemsBinding: Binding<[DailyTrackItem]> {
        kind == .zayi ? $store.data.zayi : $store.data.ikram
    }

    private var items: [DailyTrackItem] {
        kind == .zayi ? store.data.zayi : store.data.ikram
    }

    private var filteredIndices: [Int] {
        items.indices.filter { idx in
            searchText.isEmpty || items[idx].name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grandTotal: Int { items.reduce(0) { $0 + $1.total } }
    private var dayTotal: Int { items.reduce(0) { $0 + $1.count(forDay: selectedDay) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                daySelector
                Divider()
                list
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Ürün ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PeriodMenu() }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(kind.title).font(.headline)
                        Text("Toplam: \(grandTotal)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if selectedDay > store.data.daysInMonth { selectedDay = 1 }
        }
    }

    private var daySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...store.data.daysInMonth, id: \.self) { day in
                        let total = items.reduce(0) { $0 + $1.count(forDay: day) }
                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day)").font(.callout.weight(.semibold))
                                Circle()
                                    .fill(total > 0 ? Color.brown : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 38, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedDay == day ? Color.brown.opacity(0.20) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedDay == day ? Color.brown : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onAppear { proxy.scrollTo(selectedDay, anchor: .center) }
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text("\(selectedDay). gün")
                    Spacer()
                    Text("Günlük toplam: \(dayTotal)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            ForEach(filteredIndices, id: \.self) { idx in
                DailyItemRow(item: itemsBinding[idx], day: selectedDay)
            }
        }
        .listStyle(.plain)
    }
}

/// Tek ürün satırı: ad + aylık toplam rozeti + seçili güne adet sayacı.
/// Satırın tamamı 31 günlük detay ekranına götürür; +/- borderless butonlar
/// ise navigasyonu tetiklemeden adedi değiştirir.
private struct DailyItemRow: View {
    @Binding var item: DailyTrackItem
    let day: Int

    private var dayCount: Int { item.count(forDay: day) }

    var body: some View {
        NavigationLink {
            DailyItemDetailView(item: $item)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).lineLimit(2)
                    if item.total > 0 {
                        Text("Aylık toplam: \(item.total)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 14) {
                    Button {
                        item.setCount(dayCount - 1, forDay: day)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .disabled(dayCount == 0)

                    Text("\(dayCount)")
                        .monospacedDigit()
                        .frame(minWidth: 26)
                        .foregroundStyle(dayCount > 0 ? .primary : .secondary)

                    Button {
                        item.setCount(dayCount + 1, forDay: day)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .font(.title3)
                .buttonStyle(.borderless)
                .foregroundStyle(.brown)
            }
        }
    }
}
