import SwiftUI

/// Reusable sheet for reporting content (photos, messages) or users.
/// Apple Guideline 1.2 compliance — users can flag objectionable content.
struct ReportContentSheet: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    // NOTE: the reason string doubles as the value written to Firestore
    // (flagReason), so it is intentionally a plain String — localizing it would
    // change stored/reported values. Only the display copy above is localized.
    private let reasons = [
        "uygunsuz içerik",
        "taciz veya zorbalık",
        "spam veya sahte hesap",
        "diğer"
    ]

    init(
        title: LocalizedStringResource = "içeriği bildir",
        subtitle: LocalizedStringResource = "bu içeriği neden bildiriyorsun?",
        onReport: @escaping (String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onReport = onReport
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(title)
                    .font(Brand.scaledFont(size: 22, weight: .semibold, relativeTo: .title3))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(Brand.scaledFont(size: 15, weight: .regular, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.5))

                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            onReport(reason)
                        } label: {
                            Text(reason)
                                .font(Brand.scaledFont(size: 16, weight: .medium, relativeTo: .body))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("iptal")
                        .font(Brand.scaledFont(size: 16, weight: .regular, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
    }
}
