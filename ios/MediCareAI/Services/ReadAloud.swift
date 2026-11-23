import AVFoundation
import NaturalLanguage

/// Takes the audio for speaking and gives it back afterwards.
protocol AudioSessionControlling {
    func activateForSpeech()
    func deactivate()
}

struct SystemAudioSession: AudioSessionControlling {
    func activateForSpeech() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }

    /// Lets music or other audio that was turned down get loud again.
    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Reads an answer aloud in the language it is written in.
@MainActor
final class ReadAloud: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let session: AudioSessionControlling
    /// The utterance being read, so a late callback for an earlier one is ignored.
    private var current: ObjectIdentifier?
    /// True between taking the audio and giving it back.
    private var holdsAudio = false

    init(session: AudioSessionControlling = SystemAudioSession()) {
        self.session = session
        super.init()
        synthesizer.delegate = self
    }

    /// - Parameter text: plain text to read, for example from `SpeechText.forMessage`.
    func toggle(_ text: String) {
        if isSpeaking {
            stop()
        } else {
            speak(text)
        }
    }

    func speak(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()
        session.activateForSpeech()
        holdsAudio = true

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.voice = Self.voice(for: text)
        current = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finished()
    }

    /// Called when the speech ends or is stopped: other audio gets loud again.
    func finished() {
        current = nil
        isSpeaking = false
        guard holdsAudio else { return }
        holdsAudio = false
        session.deactivate()
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard id == current else { return }
        finished()
    }

    private static func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let language = recognizer.dominantLanguage?.rawValue,
           let voice = AVSpeechSynthesisVoice(language: language) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }
}
