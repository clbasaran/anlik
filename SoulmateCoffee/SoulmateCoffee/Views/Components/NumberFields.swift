import SwiftUI

/// Boş bırakılabilen sayısal giriş alanı (`Double?`). Boş metin = nil
/// (Excel'deki boş hücre davranışı).
struct OptionalDecimalField: View {
    let title: String
    @Binding var value: Double?
    var suffix: String? = nil

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .onChange(of: text) { _, newValue in
                    let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                    if cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
                        value = nil
                    } else if let d = Double(cleaned) {
                        value = d
                    }
                }
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
        .onAppear { syncText() }
        .onChange(of: value) { _, _ in syncText() }
    }

    private func syncText() {
        if let value {
            let formatted = Format.number(value)
            if Double(text.replacingOccurrences(of: ",", with: ".")) != value {
                text = formatted
            }
        } else if !text.isEmpty {
            // Dışarıdan nil yapıldıysa temizle, ama kullanıcı yazarken dokunma.
            if Double(text.replacingOccurrences(of: ",", with: ".")) != nil {
                text = ""
            }
        }
    }
}

/// Zorunlu (varsayılan 0) sayısal giriş alanı (`Double`).
struct DecimalField: View {
    let title: String
    @Binding var value: Double
    var suffix: String? = "₺"

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)
                .onChange(of: text) { _, newValue in
                    let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                    value = Double(cleaned) ?? 0
                }
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
        .onAppear { syncText() }
        .onChange(of: value) { _, _ in syncText() }
    }

    /// Bağlı değer dışarıdan değişirse (ör. dönem değişimi) metni güncelle,
    /// ama kullanıcı yazarken araya girme.
    private func syncText() {
        let parsed = Double(text.replacingOccurrences(of: ",", with: "."))
        if parsed != value {
            text = value == 0 ? "" : Format.number(value)
        }
    }
}
