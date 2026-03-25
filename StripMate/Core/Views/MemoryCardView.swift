import SwiftUI

/// A compact card shown in the HistoryView header when photos from exactly
/// one year ago today exist. Tapping it opens a full memory detail view.
struct MemoryCardView: View {
    let strips: [Strip]

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let firstStrip = strips.first,
               let url = URL(string: firstStrip.smallThumbnailUrl ?? firstStrip.thumbnailUrl ?? firstStrip.imageUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\u{1F4F8}")
                        .font(.system(size: 14))
                    Text("ge\u{00E7}en y\u{0131}l bug\u{00FC}n")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("\(strips.count) an")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Full-screen view showing "today last year" memory photos.
struct MemoryDetailView: View {
    let strips: [Strip]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\u{1F4F8}")
                                .font(.system(size: 16))
                            Text("ge\u{00E7}en y\u{0131}l bug\u{00FC}n")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        if let first = strips.first {
                            Text(first.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Spacer for symmetry
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Photos grid
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(strips, id: \.id) { strip in
                            let imageUrl = URL(string: strip.thumbnailUrl ?? strip.imageUrl)
                            CachedAsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 350)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 350)
                                    .overlay {
                                        ProgressView().tint(.white.opacity(0.2))
                                    }
                            }
                            .overlay(alignment: .bottomLeading) {
                                HStack(spacing: 6) {
                                    if let city = strip.cityName {
                                        Text(city)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Text(strip.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
