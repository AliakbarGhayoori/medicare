import Foundation

final class MockAPIService: APIServicing {
    private let state = MockAPIState()

    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let result = await state.handleChat(question: question, conversationId: conversationId)

        return AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.searching(tool: "web_search"))
                for chunk in result.tokenChunks {
                    continuation.yield(.token(chunk))
                }
                continuation.yield(.done(result.donePayload))
                continuation.finish()
            }
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

private actor MockAPIState {
    struct ChatResult {
        let donePayload: ChatDonePayload
        let tokenChunks: [String]
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

    func handleChat(question: String, conversationId: String?) -> ChatResult {
        let now = Date()
        let id = conversationId ?? UUID().uuidString
        let emergency = Self.isEmergency(question)
        let citation = Citation(
            number: 1,
            title: emergency ? "Heart Attack Symptoms" : "Dizziness",
            source: "Mayo Clinic",
            url: emergency
                ? "https://www.mayoclinic.org/diseases-conditions/heart-attack/symptoms-causes/syc-20373106"
                : "https://www.mayoclinic.org/symptoms/dizziness/basics/definition/sym-20050886",
            snippet: emergency
                ? "Call emergency services immediately for possible heart attack symptoms."
                : "Dizziness can have many causes, including blood pressure and dehydration."
        )

        let assistantText = Self.assistantResponse(for: question, emergency: emergency)
        let userMessage = Message(
            id: UUID().uuidString,
            role: .user,
            content: question,
            citations: [],
            confidence: nil,
            requiresEmergencyCare: false,
            createdAt: now
        )
        let assistantMessage = Message(
            id: UUID().uuidString,
            role: .assistant,
            content: assistantText,
            citations: [citation],
            confidence: emergency ? "high" : "medium",
            requiresEmergencyCare: emergency,
            createdAt: now
        )

        var messages = messagesByConversation[id] ?? []
        messages.append(userMessage)
        messages.append(assistantMessage)
        messagesByConversation[id] = messages

        let title = (question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "New chat"
            : String(question.prefix(60)))
        if let existingIndex = conversations.firstIndex(where: { $0.id == id }) {
            let existing = conversations[existingIndex]
            conversations[existingIndex] = Conversation(
                id: id,
                title: existing.title,
                lastMessage: assistantText,
                messageCount: messages.count,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            conversations.append(
                Conversation(
                    id: id,
                    title: title,
                    lastMessage: assistantText,
                    messageCount: messages.count,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        let donePayload = ChatDonePayload(
            messageId: assistantMessage.id,
            conversationId: id,
            content: assistantText,
            citations: [citation],
            confidence: emergency ? "high" : "medium",
            requiresEmergencyCare: emergency
        )

        return ChatResult(donePayload: donePayload, tokenChunks: Self.chunk(assistantText, size: 48))
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

    private static func assistantResponse(for question: String, emergency: Bool) -> String {
        if emergency {
            return """
            This could be a medical emergency. Call 911 now, and do not drive yourself [1].

            What to do next:
            - Call 911 immediately.
            - Sit or lie down while waiting for help.
            - Keep your phone nearby and unlock your door if you can.
            """
        }

        return """
        Thanks for sharing that. Dizziness like this is often linked to dehydration, blood pressure changes, or medication side effects [1].

        What to do next:
        - Drink water and rest.
        - Notice when symptoms happen, especially after standing up.
        - Contact your doctor if symptoms continue or get worse.
        """
    }

    private static func isEmergency(_ question: String) -> Bool {
        let lower = question.lowercased()
        return lower.contains("chest pain")
            || lower.contains("can't breathe")
            || lower.contains("can’t breathe")
            || lower.contains("suicid")
            || lower.contains("kill myself")
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
