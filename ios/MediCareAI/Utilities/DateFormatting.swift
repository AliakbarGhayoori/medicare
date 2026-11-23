import Foundation

enum DateFormatting {
    static let messageTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let longDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// "Today", "Yesterday", a weekday within the last week, otherwise a short date.
    static func chatDay(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        switch relativeDay(date, now: now, calendar: calendar) {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return format(date, template: "EEEE", calendar: calendar, locale: locale)
        case .earlier: return mediumDate(date, calendar: calendar, locale: locale)
        }
    }

    /// For use inside a sentence: "today", "yesterday", "on Friday", "on Nov 13, 2026".
    static func relativeDayPhrase(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        switch relativeDay(date, now: now, calendar: calendar) {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .thisWeek, .earlier: return "on " + chatDay(date, now: now, calendar: calendar, locale: locale)
        }
    }

    private enum RelativeDay { case today, yesterday, thisWeek, earlier }

    private static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> RelativeDay {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return .yesterday
        }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday),
           date >= weekAgo, date < startOfToday {
            return .thisWeek
        }
        return .earlier
    }

    private static func format(_ date: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private static func mediumDate(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
