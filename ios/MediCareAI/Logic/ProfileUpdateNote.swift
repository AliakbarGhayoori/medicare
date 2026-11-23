import Foundation

/// The line on My health that says a chat changed the profile.
enum ProfileUpdateNote {
    static func text(
        for digest: V10Digest,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String? {
        guard digest.lastUpdateSource == "auto", let updatedAt = digest.updatedAt else { return nil }
        let day = DateFormatting.relativeDayPhrase(updatedAt, now: now, calendar: calendar, locale: locale)
        return "Updated from your chat \(day)"
    }
}
