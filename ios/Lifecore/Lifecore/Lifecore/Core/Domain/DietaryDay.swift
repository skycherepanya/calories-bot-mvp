import Foundation

public struct DietaryDay: Hashable, Sendable, Codable {
    public let key: String
    public let interval: DateInterval
    public let timeZoneID: String

    public init(key: String, interval: DateInterval, timeZoneID: String) {
        self.key = key
        self.interval = interval
        self.timeZoneID = timeZoneID
    }

    /// Computes the DietaryDay containing the given date.
    /// Boundary is 04:00 local time.
    /// If date is before 04:00 local time, it belongs to the previous calendar day's dietary day.
    /// End is 04:00 of the subsequent day.
    /// Key is formatted as yyyy-MM-dd using Gregorian calendar and the same timezone.
    public static func containing(_ date: Date, calendar: Calendar) -> DietaryDay {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone

        let comps = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let hour = comps.hour ?? 0

        // Determine base calendar day. If before 04:00 local time, shifts to previous calendar day.
        let baseDate: Date
        if hour < 4 {
            let startOfCurrentDay = gregorian.startOfDay(for: date)
            baseDate = gregorian.date(byAdding: .day, value: -1, to: startOfCurrentDay) ?? startOfCurrentDay
        } else {
            baseDate = gregorian.startOfDay(for: date)
        }

        var startComps = gregorian.dateComponents([.year, .month, .day], from: baseDate)
        startComps.hour = 4
        startComps.minute = 0
        startComps.second = 0

        let startDate = gregorian.date(from: startComps) ?? baseDate

        let nextBaseDate = gregorian.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        var endComps = gregorian.dateComponents([.year, .month, .day], from: nextBaseDate)
        endComps.hour = 4
        endComps.minute = 0
        endComps.second = 0

        let endDate = gregorian.date(from: endComps) ?? nextBaseDate

        let year = startComps.year ?? 0
        let month = startComps.month ?? 0
        let day = startComps.day ?? 0
        let key = String(format: "%04d-%02d-%02d", year, month, day)

        return DietaryDay(
            key: key,
            interval: DateInterval(start: startDate, end: endDate),
            timeZoneID: gregorian.timeZone.identifier
        )
    }

    /// Returns true if date falls in half-open interval [start, end)
    public func contains(_ date: Date) -> Bool {
        return interval.start <= date && date < interval.end
    }
}
