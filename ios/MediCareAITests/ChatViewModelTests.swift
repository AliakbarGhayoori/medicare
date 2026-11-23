import XCTest
@testable import MediCareAI

/// Plays back one scripted stream per question.
private final class ScriptedAPI: APIServicing {
    struct Script {
        var events: [ChatStreamEvent]
        var failure: Error?
    }

    private var scripts: [Script]
    private(set) var questions: [String] = []

    init(_ scripts: [Script]) {
        self.scripts = scripts
    }

    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        questions.append(question)
        let script = scripts.isEmpty ? Script(events: []) : scripts.removeFirst()
        return AsyncThrowingStream { continuation in
            for event in script.events {
                continuation.yield(event)
            }
            continuation.finish(throwing: script.failure)
        }
    }

    func fetchHistory(limit: Int, before: String?) async throws -> ConversationListResponse {
        ConversationListResponse(conversations: [], hasMore: false, nextCursor: nil)
    }

    func fetchConversation(conversationId: String, limit: Int, before: String?) async throws -> ConversationMessagesResponse {
        ConversationMessagesResponse(conversationId: conversationId, messages: [], hasMore: false, nextCursor: nil)
    }

    func fetchV10() async throws -> V10Digest { throw APIError.notFound }
    func updateV10(digest: String) async throws -> V10Digest { throw APIError.notFound }
    func revertV10() async throws -> V10Digest { throw APIError.notFound }
    func fetchSettings() async throws -> UserSettings { .default }
    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) async throws -> UserSettings { .default }
    func acceptDisclaimer(version: String) async throws -> DisclaimerAcceptResponse { throw APIError.notFound }
    func deleteAccount() async throws {}
}

private struct SilentAnalytics: AnalyticsServicing {
    func track(_ event: String, properties: [String: String]) {}
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    private let done = ChatDonePayload(
        messageId: "m1",
        conversationId: "c1",
        content: "Yes, for most people.",
        citations: [],
        confidence: "high",
        requiresEmergencyCare: false
    )

    func testErrorEventKeepsThePartialAnswer() async {
        let api = ScriptedAPI([
            .init(events: [.token("Yes, for most people.\nCoffee won't"), .error(.aiTimeout)])
        ])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("Is coffee okay with metformin?")

        XCTAssertEqual(viewModel.interruptedAnswer, "Yes, for most people.\nCoffee won't")
        XCTAssertEqual(viewModel.streamingText, "")
        XCTAssertEqual(viewModel.lastFailedQuestion, "Is coffee okay with metformin?")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testDroppedConnectionKeepsThePartialAnswer() async {
        let api = ScriptedAPI([
            .init(events: [.token("Rest helps.")], failure: APIError.networkError)
        ])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("How do I treat a cold?")

        XCTAssertEqual(viewModel.interruptedAnswer, "Rest helps.")
        XCTAssertEqual(viewModel.errorMessage, APIError.networkError.errorDescription)
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testStreamThatEndsWithoutAnAnswerStopsWaiting() async {
        let api = ScriptedAPI([.init(events: [.token("Rest helps.")])])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("How do I treat a cold?")

        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertEqual(viewModel.interruptedAnswer, "Rest helps.")
        XCTAssertEqual(viewModel.lastFailedQuestion, "How do I treat a cold?")
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testRetryDoesNotRepeatTheQuestion() async {
        let api = ScriptedAPI([
            .init(events: [.error(.aiTimeout)]),
            .init(events: [.token("Yes, for most people."), .done(done)]),
        ])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("Is coffee okay?")
        await viewModel.retryLastFailedQuestion()

        XCTAssertEqual(viewModel.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(api.questions, ["Is coffee okay?", "Is coffee okay?"])
        XCTAssertNil(viewModel.interruptedAnswer)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.lastFailedQuestion)
    }

    func testAnswerArrivesAsOneMessage() async {
        let api = ScriptedAPI([
            .init(events: [.searching(tool: "tavily_search", query: "coffee metformin"), .token("Yes"), .done(done)])
        ])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("Is coffee okay?")

        XCTAssertEqual(viewModel.messages.last?.content, "Yes, for most people.")
        XCTAssertEqual(viewModel.currentConversationId, "c1")
        XCTAssertEqual(viewModel.streamingText, "")
        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.accessibilityAnnouncement)
    }

    func testEmergencyAnswerIsAnnounced() async {
        let emergency = ChatDonePayload(
            messageId: "m2",
            conversationId: "c1",
            content: "Call now.",
            citations: [],
            confidence: "high",
            requiresEmergencyCare: true
        )
        let api = ScriptedAPI([.init(events: [.token("Call now."), .done(emergency)])])
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        await viewModel.sendMessage("I have chest pain going down my arm")

        XCTAssertEqual(
            viewModel.accessibilityAnnouncement,
            SpeechText.emergencyIntro(number: EmergencyNumber.current)
        )
    }
}
