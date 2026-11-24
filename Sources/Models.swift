import Foundation

/// Day-granularity date helpers. All comparisons are done by calendar day
/// in the local calendar — never by raw timestamps / 86400-second math.
enum Day {
    static var calendar: Calendar { Calendar.current }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Stable "yyyy-MM-dd" key for a calendar day, used for persistence.
    static func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? date
    }

    /// Whole calendar days from `from` to `to` (negative if `to` is earlier).
    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }
}

struct PackageAccount: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// First day of the package; nil means the package has not started yet.
    var startDate: Date?
    var totalDays: Int
    /// Shipped days, stored as Day.key strings ("yyyy-MM-dd").
    var shippedDayKeys: Set<String>

    init(id: UUID = UUID(),
         name: String,
         startDate: Date?,
         totalDays: Int = 30,
         shippedDayKeys: Set<String> = []) {
        self.id = id
        self.name = name
        self.startDate = startDate.map { Day.startOfDay($0) }
        self.totalDays = totalDays
        self.shippedDayKeys = shippedDayKeys
    }

    var shippedDates: [Date] {
        shippedDayKeys.compactMap { Day.date(fromKey: $0) }.sorted()
    }

    var shippedCount: Int { shippedDayKeys.count }

    var remainingCount: Int { max(totalDays - shippedCount, 0) }

    var lastDate: Date? {
        guard let startDate else { return nil }
        return Day.addDays(totalDays - 1, to: startDate)
    }

    /// The date of the n-th (0-based) grid cell, if the package has started.
    func date(forCell index: Int) -> Date? {
        guard let startDate else { return nil }
        return Day.addDays(index, to: startDate)
    }

    func isShipped(_ date: Date) -> Bool {
        shippedDayKeys.contains(Day.key(for: date))
    }

    /// Whether `date` falls inside the package window [startDate, lastDate].
    func contains(_ date: Date) -> Bool {
        guard let startDate, let lastDate else { return false }
        let day = Day.startOfDay(date)
        return day >= Day.startOfDay(startDate) && day <= Day.startOfDay(lastDate)
    }
}

struct PersistedState: Codable {
    var accounts: [PackageAccount]
    var selectedAccountID: UUID?
}
