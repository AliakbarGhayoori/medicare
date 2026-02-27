import XCTest
@testable import MediCareAI

final class MediCareAITests: XCTestCase {
    func testDefaultSettings() {
        let settings = UserSettings.default
        XCTAssertEqual(settings.fontSize, .large)
        XCTAssertFalse(settings.highContrast)
    }

    func testAPIErrorMapping() {
        let rateLimited = APIError(code: "RATE_LIMITED", message: "Too many requests")
        XCTAssertEqual(rateLimited.errorDescription, "You're sending too many requests. Please wait a moment.")
    }

    func testErrorHandlingPrefersAPIErrorMessage() {
        let error = APIError(code: "VALIDATION_ERROR", message: "Question cannot be empty.")
        XCTAssertEqual(ErrorHandling.message(for: error), "Question cannot be empty.")
    }

    func testAPIErrorRetryAfterMessage() {
        let error = APIError.rateLimited(retryAfter: 42)
        XCTAssertEqual(error.errorDescription, "You're sending too many requests. Please wait 42 seconds.")
    }

    func testMockAPIChatRoundTripPersistsConversation() async throws {
        let service = MockAPIService()
        let stream = try await service.streamChat(question: "I feel dizzy when I stand up", conversationId: nil)

        var donePayload: ChatDonePayload?
        for try await event in stream {
            if case .done(let payload) = event {
                donePayload = payload
            }
        }

        XCTAssertNotNil(donePayload)
        XCTAssertEqual(donePayload?.citations.count, 1)

        let history = try await service.fetchHistory(limit: 20, before: nil)
        XCTAssertEqual(history.conversations.count, 1)
        XCTAssertEqual(history.conversations[0].id, donePayload?.conversationId)

        let messages = try await service.fetchConversation(
            conversationId: donePayload?.conversationId ?? "",
            limit: 50,
            before: nil
        )
        XCTAssertGreaterThanOrEqual(messages.messages.count, 2)
        XCTAssertEqual(messages.messages.last?.role, .assistant)
    }

    func testMockAPISettingsAndV10Updates() async throws {
        let service = MockAPIService()

        let updatedSettings = try await service.updateSettings(fontSize: .extraLarge, highContrast: true)
        XCTAssertEqual(updatedSettings.fontSize, .extraLarge)
        XCTAssertTrue(updatedSettings.highContrast)

        let accepted = try await service.acceptDisclaimer(version: "1.0")
        XCTAssertTrue(accepted.accepted)
        XCTAssertEqual(accepted.disclaimerVersion, "1.0")

        let v10 = try await service.updateV10(digest: "Conditions: Hypertension")
        XCTAssertEqual(v10.version, 1)
        XCTAssertEqual(v10.lastUpdateSource, "manual")
    }
}
