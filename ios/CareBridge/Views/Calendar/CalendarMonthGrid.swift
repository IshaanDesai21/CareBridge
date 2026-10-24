import SwiftUI

/// Month grid with per-day dots: green = doses, red = unresolved flag, blue = meals/notes.
struct CalendarMonthGrid: View {
    /// Any date inside the month to display.
    let monthStart: Date
    /// Summaries keyed by "yyyy-MM-dd".
    let summaries: [String: CalendarDaySummary]
    @Binding var selectedDate: String

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.autoupdatingCurrent
        c.firstWeekday = Calendar.current.firstWeekday
        return c
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Leading blanks (nil) followed by each day of the month.
    private var cells: [Date?] {
        let cal = calendar
        guard let interval = cal.dateInterval(of: .month, for: monthStart),
              let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = cal.component(.weekday, from: interval.start)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var body: some View {
        let today = Date().localDateString
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date, today: today)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date, today: String) -> some View {
        let key = date.localDateString
        let summary = summaries[key]
        let isSelected = key == selectedDate
        let isToday = key == today
        let number = calendar.component(.day, from: date)
        return Button {
            selectedDate = key
        } label: {
            VStack(spacing: 3) {
                Text("\(number)")
                    .font(.subheadline).fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.cbPrimary : Color.primary))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(Color.cbPrimary)
                        } else if isToday {
                            Circle().stroke(Color.cbPrimary, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    if summary?.hasDoses == true { dot(Color.cbGreen) }
                    if summary?.hasFlag == true { dot(Color.cbRed) }
                    if summary?.hasEntries == true { dot(Color.cbPrimary) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: date, summary: summary))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }

    private func accessibilityLabel(for date: Date, summary: CalendarDaySummary?) -> String {
        var parts = [date.formatted(date: .complete, time: .omitted)]
        if summary?.hasDoses == true { parts.append("doses logged") }
        if summary?.hasFlag == true { parts.append("flagged pill check") }
        if summary?.hasEntries == true { parts.append("meals or notes") }
        return parts.joined(separator: ", ")
    }
}
