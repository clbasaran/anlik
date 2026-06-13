import SwiftUI

/// KULLANIM KILAVUZU — Excel'deki kılavuz sayfasının uygulama karşılığı.
struct GuideView: View {
    var body: some View {
        List {
            Section("Sayfalar") {
                guideRow("Stok", "Ay başı devir, alım ve sayım bilgilerini girin. Kullanım otomatik hesaplanır.", "cube.box.fill", .brown)
                guideRow("Zayi", "Günlük zayi (bozulan/dökülen) ürün adetlerini girin.", "trash.fill", .red)
                guideRow("İkram", "Günlük ikram edilen ürün adetlerini girin.", "gift.fill", .green)
                guideRow("Özet", "Ciro ve giderleri girin; kâr/zarar ve cost oranları otomatik hesaplanır.", "chart.pie.fill", .blue)
            }

            Section("Nasıl Çalışır?") {
                bullet("Her ay başında her ürünün DEVİR alanına önceki ay sonu stok değerini girin.")
                bullet("Ay içinde gelen alımları GELEN alanına ekleyin.")
                bullet("Sayım sütunlarından en az birini doldurun; ay sonu stok son dolu sayımdan alınır.")
                bullet("Ay Sonu Stok, Toplam Kullanım ve tutarlar otomatik hesaplanır — elle girmenize gerek yoktur.")
                bullet("Zayi ve İkram sekmelerinde önce gün seçin, sonra ürünlerin adedini +/- ile girin.")
            }

            Section("Hesaplama Mantığı") {
                formula("Ay Sonu Stok", "Son doldurulan sayım değeri")
                formula("Toplam Kullanım", "Devir + Gelen − Ay Sonu Stok")
                formula("Kullanım Tutarı", "Toplam Kullanım × Birim Fiyat")
                formula("Net Kullanım", "Toplam Kullanım − Zayi − İkram")
                formula("Genel Cost (%)", "Toplam Kullanım ÷ Ciro")
                formula("Aylık Net Kazanç", "Gelir Toplam − Gider Toplam")
            }

            Section("İpuçları") {
                bullet("Sağ üstteki + ile menünüze yeni ürün ekleyebilirsiniz.")
                bullet("Üst köşedeki dönem menüsünden aylar arasında geçiş yapın.")
                bullet("Ayarlar > CSV ile verileri dışa aktarıp paylaşabilirsiniz.")
            }
        }
        .navigationTitle("Kullanım Kılavuzu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideRow(_ title: String, _ desc: String, _ icon: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.brown).font(.caption)
            Text(text).font(.subheadline)
        }
    }

    private func formula(_ name: String, _ rule: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.subheadline.weight(.semibold))
            Text(rule).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { GuideView() }
}
