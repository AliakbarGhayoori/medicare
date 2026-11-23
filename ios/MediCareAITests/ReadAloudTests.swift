import XCTest
@testable import MediCareAI

private final class FakeAudioSession: AudioSessionControlling {
    private(set) var activations = 0
    private(set) var deactivations = 0

    func activateForSpeech() { activations += 1 }
    func deactivate() { deactivations += 1 }
}

/// Listen must give the audio back when it ends, so music or a call gets loud again.
@MainActor
final class ReadAloudTests: XCTestCase {
    func testFinishingGivesTheAudioBack() {
        let session = FakeAudioSession()
        let readAloud = ReadAloud(session: session)

        readAloud.speak("Rest helps.")
        XCTAssertEqual(session.activations, 1)
        readAloud.finished()

        XCTAssertEqual(session.deactivations, 1)
        XCTAssertFalse(readAloud.isSpeaking)
    }

    func testStoppingGivesTheAudioBackOnce() {
        let session = FakeAudioSession()
        let readAloud = ReadAloud(session: session)

        readAloud.speak("Rest helps.")
        readAloud.stop()
        readAloud.finished()

        XCTAssertEqual(session.deactivations, 1)
        XCTAssertFalse(readAloud.isSpeaking)
    }

    func testStoppingWhenSilentLeavesTheAudioAlone() {
        let session = FakeAudioSession()
        let readAloud = ReadAloud(session: session)

        readAloud.stop()

        XCTAssertEqual(session.deactivations, 0)
    }
}
