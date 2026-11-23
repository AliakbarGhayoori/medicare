import XCTest
@testable import MediCareAI

@MainActor
final class SessionTests: XCTestCase {
    func testResetSessionStateForgetsTheAccount() async throws {
        let context = AppContext()
        let stream = try await context.apiService.streamChat(question: "I feel dizzy", conversationId: nil)
        for try await _ in stream {}
        _ = try await context.apiService.updateV10(digest: "Conditions:\n- Asthma")
        _ = try await context.apiService.updateSettings(fontSize: .extraLarge, highContrast: true)

        await context.conversationListViewModel.loadInitial()
        await context.v10ViewModel.load()
        await context.settingsViewModel.load()
        XCTAssertFalse(context.conversationListViewModel.conversations.isEmpty)
        XCTAssertNotNil(context.v10ViewModel.digest)
        XCTAssertTrue(context.settingsViewModel.settings.highContrast)

        context.resetSessionState()

        XCTAssertTrue(context.conversationListViewModel.conversations.isEmpty)
        XCTAssertNil(context.v10ViewModel.digest)
        XCTAssertEqual(context.v10ViewModel.editableDigest, "")
        XCTAssertEqual(context.settingsViewModel.settings, .default)
    }

    func testEachChatGetsItsOwnViewModel() {
        let context = AppContext()
        XCTAssertFalse(context.makeChatViewModel() === context.makeChatViewModel())
    }
}
