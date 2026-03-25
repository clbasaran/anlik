import SwiftUI
import SwiftData

/// Full-screen album view showing all photos exchanged between two friends, grouped by month.
public struct SharedMomentsView: View {
    let friendName: String
    let strips: [Strip]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if strips.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            headerSection
                            memoryHighlights
                            monthSections
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ortak album")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(friendName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Label("\(strips.count) foto", systemImage: "photo.fill")
                if let duration = friendshipDuration {
                    Label(duration, systemImage: "clock.fill")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Memory Highlights

    private var memoryHighlights: some View {
        let sorted = strips.sorted { $0.timestamp < $1.timestamp }
        return Group {
            if let first = sorted.first, let last = sorted.last, sorted.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("anlar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 12) {
                        memoryCard(strip: first, label: "ilk foto")
                        memoryCard(strip: last, label: "en son")
                    }
                }
            }
        }
    }

    private func memoryCard(strip: Strip, label: String) -> some View {
        VStack(spacing: 6) {
            CachedAsyncImage(url: thumbnailURL(for: strip)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text(strip.timestamp.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Month Sections

    private var monthSections: some View {
        let grouped = groupedByMonth
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            let lhsDate = Calendar.current.date(from: lhs) ?? .distantPast
            let rhsDate = Calendar.current.date(from: rhs) ?? .distantPast
            return lhsDate > rhsDate
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

        return LazyVStack(spacing: 20) {
            ForEach(sortedKeys, id: \.self) { key in
                if let monthStrips = grouped[key] {
                    VStack(alignment: .leading, spacing: 10) {
                        // Section header: "Mart 2026"
                        Text(monthYearString(from: key))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(monthStrips.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { strip in
                                CachedAsyncImage(url: thumbnailURL(for: strip)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                }
                                .frame(minHeight: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("henuz ortak foto yok")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private var groupedByMonth: [DateComponents: [Strip]] {
        Dictionary(grouping: strips) { strip in
            Calendar.current.dateComponents([.year, .month], from: strip.timestamp)
        }
    }

    private func monthYearString(from components: DateComponents) -> String {
        guard let year = components.year, let month = components.month,
              let date = Calendar.current.date(from: components) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "LLLL yyyy"
        let result = formatter.string(from: date)
        // Capitalize first letter
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private func thumbnailURL(for strip: Strip) -> URL? {
        if let small = strip.smallThumbnailUrl, let url = URL(string: small) {
            return url
        }
        if let thumb = strip.thumbnailUrl, let url = URL(string: thumb) {
            return url
        }
        return URL(string: strip.imageUrl)
    }

    private var friendshipDuration: String? {
        let sorted = strips.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first else { return nil }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: first.timestamp, to: Date())
        if let years = components.year, years > 0 {
            return "\(years) yil"
        } else if let months = components.month, months > 0 {
            return "\(months) ay"
        } else if let days = components.day {
            return "\(max(days, 1)) gun"
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    SharedMomentsView(
        friendName: "Ahmet",
        strips: []
    )
    .preferredColorScheme(.dark)
}
