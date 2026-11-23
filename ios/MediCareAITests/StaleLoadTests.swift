import XCTest
@testable import MediCareAI

/// Holds every request until the test opens it, to act out a slow network.
private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func pass() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
            } else {
                waiting.append(continuation)
                lock.unlock()
            }
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let held = waiting
        waiting = []
        lock.unlock()
        held.forEach { $0.resume() }
    }

    var hasWaiting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !waiting.isEmpty
    }

    /// - Returns: false if no request arrived within two seconds.
    func waitForARequest() async -> Bool {
        for _ in 0..<1000 where !hasWaiting {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        return hasWaiting
    }
}

/// Answers like the server, but only once the gate opens.
private final class SlowAPI: APIServicing {
    let gate = Gate()
    private(set) var questions: [String] = []

    private let date = Date(timeIntervalSince1970: 1_795_435_200)

    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        questions.append(question)
        return AsyncThrowingStream { $0.finish() }
    }

    func fetchHistory(limit: Int, before: String?) async throws -> ConversationListResponse {
        await gate.pass()
        let chat = Conversation(
            id: "c1", title: "Knees", lastMessage: "Rest helps.", messageCount: 2, createdAt: date, updatedAt: date
        )
        return ConversationListResponse(conversations: [chat], hasMore: true, nextCursor: "next")
    }

    func fetchConversation(conversationId: String, limit: Int, before: String?) async throws -> ConversationMessagesResponse {
        await gate.pass()
        let messages = [
            Message(id: "u1", role: .user, content: "Why do my knees hurt?", citations: [], confidence: nil,
                    requiresEmergencyCare: false, createdAt: date),
            Message(id: "a1", role: .assistant, content: "Rest helps.", citations: [], confidence: "high",
                    requiresEmergencyCare: false, createdAt: date),
        ]
        return ConversationMessagesResponse(conversationId: conversationId, messages: messages, hasMore: false, nextCursor: nil)
    }

    func fetchV10() async throws -> V10Digest {
        await gate.pass()
        return V10Digest(digest: "Conditions:\n- Asthma", previousDigest: nil, canRevert: false, version: 2,
                         updatedAt: date, lastUpdateSource: "manual")
    }

    func updateV10(digest: String) async throws -> V10Digest { throw APIError.notFound }
    func revertV10() async throws -> V10Digest { throw APIError.notFound }

    func fetchSettings() async throws -> UserSettings {
        await gate.pass()
        return UserSettings(fontSize: .extraLarge, highContrast: true, disclaimerAcceptedAt: nil, disclaimerVersion: nil)
    }

    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) async throws -> UserSettings { .default }
    func acceptDisclaimer(version: String) async throws -> DisclaimerAcceptResponse { throw APIError.notFound }
    func deleteAccount() async throws {}
}

private struct SilentAnalytics: AnalyticsServicing {
    func track(_ event: String, properties: [String: String]) {}
}

/// Data for the account that just signed out must not come back when a slow request finishes.
@MainActor
final class StaleLoadTests: XCTestCase {
    func testChatListArrivingAfterSignOutIsDropped() async {
        let api = SlowAPI()
        let viewModel = ConversationListViewModel(apiService: api, analytics: SilentAnalytics())

        let load = Task { await viewModel.loadInitial() }
        let requested = await api.gate.waitForARequest()
        XCTAssertTrue(requested)
        viewModel.reset()
        api.gate.open()
        await load.value

        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertFalse(viewModel.hasMore)
    }

    func testHealthProfileArrivingAfterSignOutIsDropped() async {
        let api = SlowAPI()
        let viewModel = V10ViewModel(apiService: api, analytics: SilentAnalytics())

        let load = Task { await viewModel.load() }
        let requested = await api.gate.waitForARequest()
        XCTAssertTrue(requested)
        viewModel.reset()
        api.gate.open()
        await load.value

        XCTAssertNil(viewModel.digest)
        XCTAssertEqual(viewModel.editableDigest, "")
    }

    func testSettingsArrivingAfterSignOutAreDropped() async {
        let api = SlowAPI()
        let viewModel = SettingsViewModel(apiService: api, analytics: SilentAnalytics())

        let load = Task { await viewModel.load() }
        let requested = await api.gate.waitForARequest()
        XCTAssertTrue(requested)
        viewModel.reset()
        api.gate.open()
        await load.value

        XCTAssertEqual(viewModel.settings, .default)
    }

    func testNothingIsSentWhileAChatOpens() async {
        let api = SlowAPI()
        let viewModel = ChatViewModel(apiService: api, analytics: SilentAnalytics())

        let opening = Task { await viewModel.loadConversation(conversationId: "c1") }
        let requested = await api.gate.waitForARequest()
        XCTAssertTrue(requested)
        XCTAssertTrue(viewModel.isLoadingConversation)

        await viewModel.sendMessage("And what about my hips?")
        XCTAssertEqual(api.questions, [], "A question can't be sent until the chat is open")

        api.gate.open()
        await opening.value
        XCTAssertFalse(viewModel.isLoadingConversation)
        XCTAssertEqual(viewModel.messages.map(\.id), ["u1", "a1"])
    }
}
