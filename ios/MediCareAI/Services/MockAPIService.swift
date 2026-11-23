import Foundation

/// An in-memory backend for development, unit tests and UI tests. Answers use the same
/// sectioned layout the real backend is asked for.
final class MockAPIService: APIServicing {
    private let state: MockAPIState

    /// - Parameter seeded: starts with sample chats and a health profile (for screenshots).
    init(seeded: Bool = false) {
        state = MockAPIState(seeded: seeded)
    }

    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let result = await state.handleChat(question: question, conversationId: conversationId)

        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.searching(tool: "tavily_search", query: result.searchQuery))
                try? await Task.sleep(for: .milliseconds(150))
                for chunk in result.tokenChunks {
                    continuation.yield(.token(chunk))
                    try? await Task.sleep(for: .milliseconds(20))
                }
                continuation.yield(.done(result.donePayload))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fetchHistory(limit: Int, before: String?) async throws -> ConversationListResponse {
        await state.fetchHistory(limit: limit, before: before)
    }

    func fetchConversation(conversationId: String, limit: Int, before: String?) async throws -> ConversationMessagesResponse {
        await state.fetchConversation(conversationId: conversationId, limit: limit, before: before)
    }

    func fetchV10() async throws -> V10Digest {
        await state.fetchV10()
    }

    func updateV10(digest: String) async throws -> V10Digest {
        await state.updateV10(digest: digest)
    }

    func revertV10() async throws -> V10Digest {
        await state.revertV10()
    }

    func fetchSettings() async throws -> UserSettings {
        await state.fetchSettings()
    }

    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) async throws -> UserSettings {
        await state.updateSettings(fontSize: fontSize, highContrast: highContrast)
    }

    func acceptDisclaimer(version: String) async throws -> DisclaimerAcceptResponse {
        await state.acceptDisclaimer(version: version)
    }

    func deleteAccount() async throws {
        await state.deleteAccount()
    }
}

// MARK: - Sample answers

private struct MockAnswer {
    let searchQuery: String
    let text: String
    let citations: [Citation]
    let requiresEmergencyCare: Bool

    static func source(_ number: Int, _ title: String, _ domain: String, _ path: String, _ snippet: String) -> Citation {
        Citation(number: number, title: title, source: domain, url: "https://www.\(domain)\(path)", snippet: snippet)
    }

    static func forQuestion(_ question: String) -> MockAnswer {
        let lower = question.lowercased()
        if isEmergency(lower) { return emergency }
        if lower.contains("coffee") || lower.contains("metformin") { return coffee }
        if lower.contains("knee") { return knees }
        if lower.contains("sleep") || lower.contains("wake up") { return sleep }
        return dizziness
    }

    static func isEmergency(_ lower: String) -> Bool {
        lower.contains("chest pain")
            || lower.contains("pain in my chest")
            || lower.contains("can't breathe")
            || lower.contains("can’t breathe")
            || lower.contains("suicid")
            || lower.contains("kill myself")
    }

    static let coffee = MockAnswer(
        searchQuery: "coffee metformin morning",
        text: """
        Yes, for most people coffee is fine with metformin.
        Coffee does not stop metformin from working [1]. Caffeine can raise blood sugar a little in some people, so notice how you feel after a cup [2].
        Do this:
        - Keep taking metformin with breakfast, as prescribed [3].
        - Have one or two cups a day, without sugar.
        Watch for:
        - A racing heart or an upset stomach after coffee. Tell your doctor if it happens.
        """,
        citations: [
            source(1, "Metformin: side effects and interactions", "mayoclinic.org", "/drugs-supplements/metformin-oral-route/description/drg-20067074",
                   "No interaction is known between metformin and caffeine. Take metformin with meals to reduce stomach side effects."),
            source(2, "Caffeine and diabetes", "diabetes.org.uk", "/living-with-diabetes/eating/caffeine",
                   "Caffeine can make blood sugar rise for some people with type 2 diabetes. Watch how your levels respond."),
            source(3, "How and when to take metformin", "nhs.uk", "/medicines/metformin/how-and-when-to-take-metformin/",
                   "Take metformin with a meal to lower the chance of side effects."),
        ],
        requiresEmergencyCare: false
    )

    static let dizziness = MockAnswer(
        searchQuery: "dizziness when standing up older adults",
        text: """
        Dizziness when you stand up is common and is often caused by a short drop in blood pressure.
        It can come from not drinking enough, from some blood pressure medicines, or from standing up quickly [1]. It usually passes within a few seconds [2].
        Do this:
        - Stand up slowly, and sit on the edge of the bed for a minute first.
        - Drink water through the day.
        - Ask your doctor to check your blood pressure lying down and standing.
        Watch for:
        - Fainting, falls or chest pain. Get help straight away.
        """,
        citations: [
            source(1, "Orthostatic hypotension (postural hypotension)", "mayoclinic.org", "/diseases-conditions/orthostatic-hypotension/symptoms-causes/syc-20352548",
                   "Common causes include dehydration, heart problems and some medicines for high blood pressure."),
            source(2, "Low blood pressure (hypotension)", "nhs.uk", "/conditions/low-blood-pressure-hypotension/",
                   "Dizziness when standing up usually only lasts a few seconds."),
        ],
        requiresEmergencyCare: false
    )

    static let knees = MockAnswer(
        searchQuery: "knee pain stairs older adults exercise",
        text: """
        Knee pain on the stairs is often caused by wear in the joint, and gentle exercise usually helps.
        Strong thigh muscles take pressure off the knee [1]. Walking and cycling are safe for most people with knee osteoarthritis [2].
        Do this:
        - Lead with your stronger leg going up, and your sore leg going down.
        - Try 10 minutes a day of the exercises your doctor or physiotherapist suggests.
        Watch for:
        - A hot, swollen knee or pain that wakes you at night. See your doctor.
        """,
        citations: [
            source(1, "Knee pain: exercises", "nhs.uk", "/live-well/exercise/knee-exercises/",
                   "Strengthening the muscles around the knee can reduce pain."),
            source(2, "Osteoarthritis of the knee", "arthritis.org", "/diseases/osteoarthritis",
                   "Low-impact activity such as walking, swimming and cycling helps most people."),
        ],
        requiresEmergencyCare: false
    )

    static let sleep = MockAnswer(
        searchQuery: "early waking older adults sleep tips",
        text: """
        Waking early is common as we get older, and a few habits often help.
        Sleep becomes lighter with age, so noise and light wake us more easily [1]. Daylight in the morning helps set your body clock [2].
        Do this:
        - Get up at the same time every day, even after a bad night.
        - Spend time outside in the morning light.
        - Avoid naps after 3 pm.
        Watch for:
        - Low mood, loud snoring or gasping at night. Talk to your doctor.
        """,
        citations: [
            source(1, "Sleep and older adults", "nia.nih.gov", "/health/sleep/good-nights-sleep",
                   "Older adults often sleep more lightly and wake up more during the night."),
            source(2, "Insomnia", "nhs.uk", "/conditions/insomnia/",
                   "Keep regular sleeping hours and get daylight during the day."),
        ],
        requiresEmergencyCare: false
    )

    static var emergency: MockAnswer {
        let number = EmergencyNumber.current
        return MockAnswer(
            searchQuery: "chest pain spreading to arm",
            text: """
            Call \(number) now. Chest pain that spreads to your arm can be a heart attack [1].
            Do not drive yourself to hospital. An ambulance can start treatment on the way [2].
            Do this:
            - Call \(number) and say you have chest pain.
            - Sit down and rest while you wait.
            - Unlock your front door and tell someone nearby.
            Watch for:
            - Fainting or trouble breathing. Tell the call handler straight away.
            """,
            citations: [
                source(1, "Heart attack: symptoms", "nhs.uk", "/conditions/heart-attack/symptoms/",
                       "Chest pain that spreads to the arms, jaw, neck or back can be a heart attack."),
                source(2, "Heart attack: what to do", "bhf.org.uk", "/informationsupport/conditions/heart-attack",
                       "Call for an ambulance straight away. Do not drive yourself."),
            ],
            requiresEmergencyCare: true
        )
    }
}

// MARK: - State

private actor MockAPIState {
    struct ChatResult {
        let donePayload: ChatDonePayload
        let tokenChunks: [String]
        let searchQuery: String
    }

    private var conversations: [Conversation] = []
    private var messagesByConversation: [String: [Message]] = [:]
    private var v10 = V10Digest(
        digest: nil,
        previousDigest: nil,
        canRevert: false,
        version: 0,
        updatedAt: nil,
        lastUpdateSource: nil
    )
    private var settings = UserSettings.default

    init(seeded: Bool) {
        guard seeded else { return }
        let now = Date()
        let day: TimeInterval = 24 * 60 * 60
        let samples: [(question: String, answer: MockAnswer, date: Date)] = [
            ("I wake up at 4 am every night. What can I do?", .sleep, now - 9 * day),
            ("Why do my knees hurt on the stairs?", .knees, now - 3 * day),
            ("Is coffee okay with metformin in the morning?", .coffee, now - 2 * 60 * 60),
        ]
        var conversations: [Conversation] = []
        var messages: [String: [Message]] = [:]
        for sample in samples {
            let id = UUID().uuidString
            let pair = Self.messagePair(question: sample.question, answer: sample.answer, at: sample.date)
            messages[id] = [pair.user, pair.assistant]
            conversations.append(
                Conversation(
                    id: id,
                    title: sample.question,
                    lastMessage: Self.preview(sample.answer.text),
                    messageCount: 2,
                    createdAt: sample.date,
                    updatedAt: sample.date
                )
            )
        }
        self.conversations = conversations
        self.messagesByConversation = messages
        self.v10 = Self.sampleProfile(updatedAt: now - 60 * 60)
    }

    func handleChat(question: String, conversationId: String?) -> ChatResult {
        let answer = MockAnswer.forQuestion(question)
        let id = conversationId ?? UUID().uuidString
        let assistant = record(question: question, answer: answer, in: id, at: Date())

        let donePayload = ChatDonePayload(
            messageId: assistant.id,
            conversationId: id,
            content: answer.text,
            citations: answer.citations,
            confidence: "high",
            requiresEmergencyCare: answer.requiresEmergencyCare
        )
        return ChatResult(
            donePayload: donePayload,
            tokenChunks: Self.chunk(answer.text, size: 24),
            searchQuery: answer.searchQuery
        )
    }

    private static func messagePair(question: String, answer: MockAnswer, at date: Date) -> (user: Message, assistant: Message) {
        let user = Message(
            id: UUID().uuidString,
            role: .user,
            content: question,
            citations: [],
            confidence: nil,
            requiresEmergencyCare: false,
            createdAt: date
        )
        let assistant = Message(
            id: UUID().uuidString,
            role: .assistant,
            content: answer.text,
            citations: answer.citations,
            confidence: "high",
            requiresEmergencyCare: answer.requiresEmergencyCare,
            createdAt: date.addingTimeInterval(1)
        )
        return (user, assistant)
    }

    /// Like the server: the first 100 characters of the latest answer.
    private static func preview(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
    }

    private func record(question: String, answer: MockAnswer, in id: String, at date: Date) -> Message {
        let pair = Self.messagePair(question: question, answer: answer, at: date)
        var messages = messagesByConversation[id] ?? []
        messages.append(pair.user)
        messages.append(pair.assistant)
        messagesByConversation[id] = messages
        let assistantMessage = pair.assistant

        let preview = Self.preview(answer.text)
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            let existing = conversations[index]
            conversations[index] = Conversation(
                id: id,
                title: existing.title,
                lastMessage: preview,
                messageCount: messages.count,
                createdAt: existing.createdAt,
                updatedAt: date
            )
        } else {
            let title = question.trimmingCharacters(in: .whitespacesAndNewlines)
            conversations.append(
                Conversation(
                    id: id,
                    title: title.isEmpty ? "New conversation" : String(title.prefix(100)),
                    lastMessage: preview,
                    messageCount: messages.count,
                    createdAt: date,
                    updatedAt: date
                )
            )
        }
        return assistantMessage
    }

    private static func sampleProfile(updatedAt: Date) -> V10Digest {
        let before = """
        About me:
        - 74 years old, lives alone
        Conditions:
        - Type 2 diabetes
        - High blood pressure
        Medicines:
        - Metformin 500 mg with breakfast
        - Amlodipine 5 mg in the evening
        Allergies:
        - Penicillin
        """
        return V10Digest(
            digest: before + "\nRecent concerns:\n- Dizzy spells in the morning",
            previousDigest: before,
            canRevert: true,
            version: 3,
            updatedAt: updatedAt,
            lastUpdateSource: "auto"
        )
    }

    func fetchHistory(limit: Int, before: String?) -> ConversationListResponse {
        let sorted = conversations.sorted { $0.updatedAt > $1.updatedAt }
        let startIndex: Int
        if let before, let idx = sorted.firstIndex(where: { $0.id == before }) {
            startIndex = idx + 1
        } else {
            startIndex = 0
        }

        let endIndex = min(startIndex + max(1, limit), sorted.count)
        let page = Array(sorted[startIndex..<endIndex])
        let hasMore = endIndex < sorted.count
        let nextCursor = hasMore ? page.last?.id : nil

        return ConversationListResponse(
            conversations: page,
            hasMore: hasMore,
            nextCursor: nextCursor
        )
    }

    func fetchConversation(conversationId: String, limit: Int, before: String?) -> ConversationMessagesResponse {
        let allMessages = messagesByConversation[conversationId] ?? []
        let sorted = allMessages.sorted { $0.createdAt < $1.createdAt }
        let anchorIndex: Int
        if let before, let idx = sorted.firstIndex(where: { $0.id == before }) {
            anchorIndex = idx
        } else {
            anchorIndex = sorted.count
        }

        let end = max(0, anchorIndex)
        let start = max(0, end - max(1, limit))
        let page = Array(sorted[start..<end])
        let hasMore = start > 0
        let nextCursor = hasMore ? page.first?.id : nil

        return ConversationMessagesResponse(
            conversationId: conversationId,
            messages: page,
            hasMore: hasMore,
            nextCursor: nextCursor
        )
    }

    func fetchV10() -> V10Digest {
        v10
    }

    func updateV10(digest: String) -> V10Digest {
        let previous = v10.digest
        v10 = V10Digest(
            digest: digest,
            previousDigest: previous,
            canRevert: previous != nil && previous != digest,
            version: v10.version + 1,
            updatedAt: Date(),
            lastUpdateSource: "manual"
        )
        return v10
    }

    func revertV10() -> V10Digest {
        guard let previous = v10.previousDigest else { return v10 }
        v10 = V10Digest(
            digest: previous,
            previousDigest: v10.digest,
            canRevert: v10.digest != nil,
            version: v10.version + 1,
            updatedAt: Date(),
            lastUpdateSource: "manual"
        )
        return v10
    }

    func fetchSettings() -> UserSettings {
        settings
    }

    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) -> UserSettings {
        settings = UserSettings(
            fontSize: fontSize ?? settings.fontSize,
            highContrast: highContrast ?? settings.highContrast,
            disclaimerAcceptedAt: settings.disclaimerAcceptedAt,
            disclaimerVersion: settings.disclaimerVersion
        )
        return settings
    }

    func acceptDisclaimer(version: String) -> DisclaimerAcceptResponse {
        let acceptedAt = Date()
        settings = UserSettings(
            fontSize: settings.fontSize,
            highContrast: settings.highContrast,
            disclaimerAcceptedAt: acceptedAt,
            disclaimerVersion: version
        )
        return DisclaimerAcceptResponse(
            accepted: true,
            disclaimerVersion: version,
            acceptedAt: acceptedAt
        )
    }

    func deleteAccount() {
        conversations.removeAll()
        messagesByConversation.removeAll()
        v10 = V10Digest(
            digest: nil,
            previousDigest: nil,
            canRevert: false,
            version: 0,
            updatedAt: nil,
            lastUpdateSource: nil
        )
        settings = .default
    }

    private static func chunk(_ text: String, size: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var output: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            output.append(String(text[start..<end]))
            start = end
        }
        return output
    }
}
