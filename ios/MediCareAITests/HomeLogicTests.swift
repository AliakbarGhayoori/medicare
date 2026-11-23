import XCTest
@testable import MediCareAI

final class HomeLogicTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let locale = Locale(identifier: "en_US")

    /// Monday 23 November 2026, 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_795_435_200)

    private func day(_ isoDate: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoDate)!
    }

    func testNowIsAMonday() {
        XCTAssertEqual(calendar.component(.weekday, from: now), 2)
        XCTAssertEqual(calendar.component(.day, from: now), 23)
    }

    func testChatDayNamesRecentDays() {
        func label(_ isoDate: String) -> String {
            DateFormatting.chatDay(day(isoDate), now: now, calendar: calendar, locale: locale)
        }
        XCTAssertEqual(label("2026-11-23T08:00:00Z"), "Today")
        XCTAssertEqual(label("2026-11-22T20:00:00Z"), "Yesterday")
        XCTAssertEqual(label("2026-11-20T10:00:00Z"), "Friday")
        XCTAssertEqual(label("2026-11-17T10:00:00Z"), "Tuesday")
        XCTAssertEqual(label("2026-11-13T10:00:00Z"), "Nov 13, 2026")
    }

    func testRelativeDayPhraseReadsInASentence() {
        func phrase(_ isoDate: String) -> String {
            DateFormatting.relativeDayPhrase(day(isoDate), now: now, calendar: calendar, locale: locale)
        }
        XCTAssertEqual(phrase("2026-11-23T08:00:00Z"), "today")
        XCTAssertEqual(phrase("2026-11-22T20:00:00Z"), "yesterday")
        XCTAssertEqual(phrase("2026-11-20T10:00:00Z"), "on Friday")
        XCTAssertEqual(phrase("2026-11-13T10:00:00Z"), "on Nov 13, 2026")
    }

    func testChatPreviewUsesTheShortAnswer() {
        let preview = "Yes, for most people [1].\nCoffee won't stop metformin working [2]. Caffeine may raise your bl"
        XCTAssertEqual(ChatPreview.text(preview), "Yes, for most people.")
    }

    func testChatPreviewOfAnOldAnswerDropsMarkdownAndSources() {
        XCTAssertEqual(
            ChatPreview.text("**Dizziness** is often linked to dehydration [1]."),
            "Dizziness is often linked to dehydration."
        )
    }

    func testChatPreviewMarksACutOffLine() {
        let line = String(repeating: "a", count: 100)
        XCTAssertEqual(ChatPreview.text(line), line + "…")
    }

    func testChatPreviewOfNothingIsEmpty() {
        XCTAssertEqual(ChatPreview.text(""), "")
    }
}
