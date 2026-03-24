import SwiftUI

/// Full-screen view to display a legal document's content.
/// Opened from ConsentView or Settings for reading.
struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(document.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    // Balance spacer
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Version badge
                Text("v\(LegalDocument.currentVersion)")
                    .font(.system(size: 11, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 12)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                
                // Content
                ScrollView(.vertical, showsIndicators: true) {
                    Text(document.content)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }
        }
    }
}
