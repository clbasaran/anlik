import SwiftUI
import Charts

/// COST - P&L — gelir/gider girişleri, cost oranları ve aylık net kazanç.
struct SummaryView: View {
    @EnvironmentObject private var store: DataStore

    private var summary: CostSummary { CostSummary(store.data) }

    var body: some View {
        NavigationStack {
            Form {
                netProfitSection
                revenueSection
                expensesSection
                costRatiosSection
                categoryBreakdownSection
                chartSection
            }
            .navigationTitle("Kâr / Zarar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PeriodMenu() }
            }
        }
    }

    // MARK: - Net kazanç vurgusu

    private var netProfitSection: some View {
        Section {
            VStack(spacing: 6) {
                Text("AYLIK NET KAZANÇ")
                    .font(.caption).foregroundStyle(.secondary)
                Text(Format.tl(summary.netKazanc))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(summary.netKazanc >= 0 ? .green : .red)
                HStack(spacing: 16) {
                    Label(Format.tl(summary.gelirToplam), systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Label(Format.tl(summary.giderToplam), systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Gelir

    private var revenueSection: some View {
        Section("Gelir") {
            DecimalField(title: "Ciro", value: $store.data.ciro)
            DecimalField(title: "Çalışan Gün Sayısı", value: $store.data.calisanGunSayisi, suffix: "gün")
            LabeledValueRow(label: "Günlük Ciro Ort.", value: Format.tl(summary.gunlukCiroOrt))
        }
    }

    // MARK: - Giderler

    private var expensesSection: some View {
        Section("Giderler") {
            LabeledValueRow(label: "COST (Malzeme)", value: Format.tl(summary.costMalzeme))
            DecimalField(title: "Personel Maliyet", value: $store.data.personelMaliyet)
            DecimalField(title: "Kira", value: $store.data.kira)
            DecimalField(title: "Elektrik", value: $store.data.elektrik)
            DecimalField(title: "Su", value: $store.data.su)
            DecimalField(title: "Doğalgaz", value: $store.data.dogalgaz)
            DecimalField(title: "İnternet", value: $store.data.internet)
            DecimalField(title: "Diğer Giderler / Vergiler", value: $store.data.digerGiderler)
            LabeledValueRow(label: "Gider Toplam", value: Format.tl(summary.giderToplam), emphasized: true)
        }
    }

    // MARK: - Cost oranları

    private var costRatiosSection: some View {
        Section("Cost Oranları (Ciroya Göre)") {
            LabeledValueRow(label: "Cost Gıda", value: Format.pct(summary.costGida))
            LabeledValueRow(label: "Cost Sarf", value: Format.pct(summary.costSarf))
            LabeledValueRow(label: "Cost Temizlik", value: Format.pct(summary.costTemizlik))
            LabeledValueRow(label: "Genel Cost", value: Format.pct(summary.costGenel), emphasized: true)
            Divider()
            LabeledValueRow(label: "İkram / Ciro Oranı", value: Format.pct(summary.ikramCiroOrani))
            LabeledValueRow(label: "Zayi / Ciro Oranı", value: Format.pct(summary.zayiCiroOrani))
        }
    }

    // MARK: - Kategori kırılımı

    private var categoryBreakdownSection: some View {
        Section("Kategori Bazlı Kullanım") {
            ForEach(summary.categories) { cat in
                HStack {
                    Label(cat.group.displayName, systemImage: cat.group.systemImage)
                        .foregroundStyle(cat.group.tint)
                        .font(.subheadline)
                    Spacer()
                    Text(Format.tl(cat.kullanimTL))
                        .font(.subheadline.weight(.medium))
                }
            }
            LabeledValueRow(label: "Toplam Kullanım", value: Format.tl(summary.totalKullanim), emphasized: true)
        }
    }

    // MARK: - Grafik

    private var chartSection: some View {
        Section("Kullanım Dağılımı") {
            let data = summary.categories.filter { $0.kullanimTL > 0 }
            if data.isEmpty {
                Text("Henüz veri yok. Stok girişlerini yaptığınızda dağılım burada görünür.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(data) { cat in
                    SectorMark(
                        angle: .value("Tutar", cat.kullanimTL),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(cat.group.tint)
                    .annotation(position: .overlay) {
                        if cat.kullanimTL / max(summary.totalKullanim, 1) > 0.08 {
                            Text(Format.pct(cat.kullanimTL / max(summary.totalKullanim, 1)))
                                .font(.caption2).foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 220)

                ForEach(data) { cat in
                    HStack {
                        Circle().fill(cat.group.tint).frame(width: 10, height: 10)
                        Text(cat.group.displayName).font(.caption)
                        Spacer()
                        Text(Format.pct(cat.kullanimTL / max(summary.totalKullanim, 1)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    SummaryView().environmentObject(DataStore())
}
