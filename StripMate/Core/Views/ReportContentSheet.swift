import SwiftUI

/// Reusable sheet for reporting content (photos, messages) or users.
/// Apple Guideline 1.2 compliance — users can flag objectionable content.
struct ReportContentSheet: View {
    let title: String
    let subtitle: String
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let reasons = [
        "uygunsuz içerik",
        "taciz veya zorbalık",
        "spam veya sahte hesap",
        "diğer"
    ]

    init(
        title: String = "içeriği bildir",
        subtitle: String = "bu içeriği neden bildiriyorsun?",
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))

                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            onReport(reason)
                        } label: {
                            Text(reason)
                                .font(.system(size: 16, weight: .medium))
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
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
    }
}
