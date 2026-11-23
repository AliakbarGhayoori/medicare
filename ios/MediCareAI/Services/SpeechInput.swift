import AVFoundation
import Speech

/// Lets through recognizer results from the current listening session only, so a late
/// result can't refill the question field after it was sent.
struct TranscriptGate {
    private(set) var session = 0
    private(set) var isOpen = false

    mutating func open() -> Int {
        session += 1
        isOpen = true
        return session
    }

    mutating func close() {
        isOpen = false
    }

    func accepts(_ id: Int) -> Bool {
        isOpen && id == session
    }
}

/// Turns what the person says into text for the question field.
@MainActor
final class SpeechInput: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published var problem: String?

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var gate = TranscriptGate()

    func toggle() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        problem = nil
        guard await Self.requestPermissions() else {
            problem = "To ask by talking, allow the microphone and speech recognition for MediCare AI in Settings."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = "Talking isn't available right now. You can type your question instead."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = audioEngine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()

            transcript = ""
            isListening = true
            let listening = gate.open()
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = error != nil || result?.isFinal == true
                Task { @MainActor in
                    // A result that arrives after stop (for example after the question was
                    // sent) must not refill the question field or stop a newer session.
                    guard let self, self.gate.accepts(listening) else { return }
                    if let text { self.transcript = text }
                    if finished { self.stop() }
                }
            }
        } catch {
            problem = "The microphone couldn't start. You can type your question instead."
            stop()
        }
    }

    func stop() {
        gate.close()
        guard isListening || task != nil || request != nil else { return }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
