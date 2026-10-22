import Foundation

extension Date {
    /// "yyyy-MM-dd" in the device's current time zone (the patient's local calendar day).
    var localDateString: String {
        Date.localDateFormatter.string(from: self)
    }

    /// Parses a "yyyy-MM-dd" local date string to midnight of that day in the current time zone.
    static func fromLocalDateString(_ string: String) -> Date? {
        localDateFormatter.date(from: string)
    }

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
