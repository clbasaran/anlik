import SwiftUI
import SwiftData
import FirebaseAuth

struct CalendarCapsuleView: View {
    @Query(sort: \Strip.timestamp, order: .reverse) private var allStrips: [Strip]
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?
    @State private var detailPhoto: PhotoMetadata?

    // MARK: - Precomputed

    private var daysWithPhotos: Set<DateComponents> {
        var set = Set<DateComponents>()
        let cal = Calendar.current
        for strip in allStrips {
            let dc = cal.dateComponents([.year, .month, .day], from: strip.timestamp)
            set.insert(dc)
        }
        return set
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                monthNavigator
                weekdayHeaders
                calendarGrid
                if let selected = selectedDate {
                    selectedDayContent(for: selected)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $detailPhoto) { photo in
            let isMine = photo.senderId == Auth.auth().currentUser?.uid
            PhotoDetailView(photo: photo, isSentByMe: isMine)
                .presentationBackground(.black)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(String(localized: "günlük kapsül"))
                .font(Brand.scaledFont(size: 22, weight: .bold, relativeTo: .title3))
                .foregroundColor(.white)
                .tracking(-0.5)

            Spacer()

            CircleIconButton(icon: "xmark", size: 32, iconSize: 16, accessibilityLabel: "kapat") {
                dismiss()
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "önceki ay"))

            Spacer()

            Text(monthYearString(for: displayedMonth))
                .font(Brand.scaledFont(size: 16, weight: .semibold, relativeTo: .body))
                .foregroundColor(.white)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "sonraki ay"))
        }
        .padding(.bottom, 12)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        let days = [String(localized: "Pzt"), String(localized: "Sal"), String(localized: "Çar"), String(localized: "Per"), String(localized: "Cum"), String(localized: "Cmt"), String(localized: "Paz")]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(height: 28)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let slots = daysInMonth(for: displayedMonth)
        let cal = Calendar.current
        let todayComponents = cal.dateComponents([.year, .month, .day], from: Date())
        let displayedMonthValue = cal.component(.month, from: displayedMonth)
        let displayedYearValue = cal.component(.year, from: displayedMonth)
        let photoDays = daysWithPhotos

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(0..<42, id: \.self) { index in
                if let date = slots[index] {
                    let dc = cal.dateComponents([.year, .month, .day], from: date)
                    let isCurrentMonth = dc.month == displayedMonthValue && dc.year == displayedYearValue
                    let isToday = dc == todayComponents
                    let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
                    let hasPhotos = photoDays.contains(dc)

                    Button {
                        withAnimation(Brand.Animations.fadeQuick) {
                            if isSelected {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 34, height: 34)
                                } else if isToday {
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        .frame(width: 34, height: 34)
                                }

                                Text("\(dc.day ?? 0)")
                                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? .black : .white)
                            }

                            Circle()
                                .fill(hasPhotos ? Color.white : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .opacity(isCurrentMonth ? 1.0 : 0.2)
                    }
                    .frame(height: 48)
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
    }

    // MARK: - Selected Day Content

    @ViewBuilder
    private func selectedDayContent(for date: Date) -> some View {
        let strips = stripsForDay(date)

        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.top, 12)

            if strips.isEmpty {
                Text(String(localized: "bu gün foto yok"))
                    .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                HStack {
                    Text(dayHeaderString(for: date))
                        .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                        .foregroundColor(.white)

                    Spacer()

                    Text(String(localized: "\(strips.count) an"))
                        .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                        .foregroundColor(.white.opacity(0.5))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(strips, id: \.id) { strip in
                            let thumbURL = strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl
                            Button {
                                HapticsManager.playSelection()
                                detailPhoto = strip.asMetadata
                            } label: {
                                CachedAsyncImage(
                                    url: URL(string: thumbURL),
                                    content: { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 106)
                                            .clipped()
                                            .cornerRadius(10)
                                    },
                                    placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 80, height: 106)
                                    }
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityLabel(String(localized: "anı aç"))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func daysInMonth(for date: Date) -> [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date))
        else { return Array(repeating: nil, count: 42) }

        // weekday of the first day (Monday = 1 for ISO8601 style)
        var weekday = cal.component(.weekday, from: firstOfMonth)
        // Convert Sunday=1..Saturday=7 to Monday=0..Sunday=6
        weekday = (weekday + 5) % 7

        var slots: [Date?] = Array(repeating: nil, count: 42)

        // Fill previous month trailing days
        if weekday > 0 {
            for i in stride(from: weekday - 1, through: 0, by: -1) {
                let daysBack = weekday - i
                slots[i] = cal.date(byAdding: .day, value: -daysBack, to: firstOfMonth)
            }
        }

        // Fill current month days
        for day in range {
            let index = weekday + day - 1
            if index < 42 {
                slots[index] = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)
            }
        }

        // Fill next month leading days
        let filledCount = weekday + range.count
        if filledCount < 42, let nextMonthStart = cal.date(byAdding: .month, value: 1, to: firstOfMonth) {
            for i in filledCount..<42 {
                slots[i] = cal.date(byAdding: .day, value: i - filledCount, to: nextMonthStart)
            }
        }

        return slots
    }

    private func stripsForDay(_ date: Date) -> [Strip] {
        let cal = Calendar.current
        return allStrips.filter { cal.isDate($0.timestamp, inSameDayAs: date) }
    }

    private func shiftMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(Brand.Animations.fadeStandard) {
                displayedMonth = newDate
                selectedDate = nil
            }
        }
    }

    private func monthYearString(for date: Date) -> String {
        let turkishMonths = [
            "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
            "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
        ]
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        return "\(turkishMonths[month - 1]) \(year)"
    }

    private func dayHeaderString(for date: Date) -> String {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        let turkishMonths = [
            "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
            "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
        ]
        return "\(day) \(turkishMonths[month - 1])"
    }
}

#Preview {
    CalendarCapsuleView()
        .modelContainer(for: Strip.self, inMemory: true)
}
