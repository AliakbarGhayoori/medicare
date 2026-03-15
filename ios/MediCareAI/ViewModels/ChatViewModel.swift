import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingText: String = ""
    @Published var isStreaming = false
    @Published var isSearching = false
    @Published var searchingTool: String?
    @Published var searchingQuery: String?
    @Published var errorMessage: String?
    @Published var selectedCitation: Citation?
    @Published var currentConversationId: String?
    @Published var lastFailedQuestion: String?
    @Published var profileUpdatedNotice: String?

    private let apiService: APIServicing
    private let analytics: AnalyticsServicing
    private var knownV10Version: Int?

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    func setConversation(_ conversation: Conversation, preloadMessages: [Message] = []) {
        currentConversationId = conversation.id
        messages = preloadMessages
        streamingText = ""
        errorMessage = nil
        lastFailedQuestion = nil
        searchingTool = nil
        searchingQuery = nil
        profileUpdatedNotice = nil
    }

    func loadConversation(conversationId: String) async {
        errorMessage = nil
        do {
            let response = try await apiService.fetchConversation(
                conversationId: conversationId,
                limit: 50,
                before: nil
            )
            currentConversationId = response.conversationId
            messages = response.messages
            analytics.track(
                "conversation_loaded",
                properties: ["conversationId": conversationId]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }

    func startNewConversation() {
        currentConversationId = nil
        messages = []
        streamingText = ""
        errorMessage = nil
        lastFailedQuestion = nil
        searchingTool = nil
        searchingQuery = nil
        profileUpdatedNotice = nil
    }

    func sendMessage(_ content: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let userMessage = Message(
            id: UUID().uuidString,
            role: .user,
            content: trimmed,
            citations: [],
            confidence: nil,
            requiresEmergencyCare: false,
            createdAt: .now
        )
        messages.append(userMessage)

        isStreaming = true
        isSearching = false
        searchingTool = nil
        searchingQuery = nil
        streamingText = ""
        errorMessage = nil
        lastFailedQuestion = nil
        await primeKnownV10VersionIfNeeded()
        analytics.track(
            "question_asked",
            properties: ["hasConversation": currentConversationId == nil ? "false" : "true"]
        )

        do {
            let stream = try await apiService.streamChat(
                question: trimmed,
                conversationId: currentConversationId
            )

            for try await event in stream {
                switch event {
                case .token(let text):
                    isSearching = false
                    searchingTool = nil
                    searchingQuery = nil
                    streamingText += text

                case .searching(let tool, let query):
                    isSearching = true
                    searchingTool = tool
                    searchingQuery = query

                case .done(let payload):
                    currentConversationId = payload.conversationId
                    let finalContent = payload.content ?? streamingText
                    let assistant = Message(
                        id: payload.messageId,
                        role: .assistant,
                        content: finalContent,
                        citations: payload.citations,
                        confidence: payload.confidence,
                        requiresEmergencyCare: payload.requiresEmergencyCare,
                        createdAt: .now
                    )
                    messages.append(assistant)
                    streamingText = ""
                    isStreaming = false
                    isSearching = false
                    searchingTool = nil
                    searchingQuery = nil
                    analytics.track(
                        "response_received",
                        properties: [
                            "citationCount": String(payload.citations.count),
                            "hasEmergency": payload.requiresEmergencyCare ? "true" : "false",
                            "confidence": payload.confidence
                        ]
                    )
                    await checkForAutoProfileUpdate()

                case .error(let apiError):
                    isStreaming = false
                    isSearching = false
                    searchingTool = nil
                    searchingQuery = nil
                    streamingText = ""
                    errorMessage = apiError.errorDescription
                    lastFailedQuestion = trimmed
                    analytics.track("error_occurred", properties: ["code": apiError.analyticsCode])
                }
            }
        } catch {
            isStreaming = false
            isSearching = false
            searchingTool = nil
            searchingQuery = nil
            streamingText = ""
            errorMessage = ErrorHandling.message(for: error)
            lastFailedQuestion = trimmed
            let code = (error as? APIError)?.analyticsCode ?? "UNKNOWN"
            analytics.track("error_occurred", properties: ["code": code])
        }
    }

    func retryLastFailedQuestion() async {
        guard let lastFailedQuestion else { return }
        analytics.track("chat_retry", properties: [:])
        await sendMessage(lastFailedQuestion)
    }

    func didTapCitation(_ citation: Citation) {
        selectedCitation = citation
        analytics.track(
            "citation_tapped",
            properties: [
                "source": citation.source,
                "number": String(citation.number)
            ]
        )
    }

    func dismissProfileUpdatedNotice() {
        profileUpdatedNotice = nil
    }

    private func checkForAutoProfileUpdate() async {
        do {
            let digest = try await apiService.fetchV10()
            if let known = knownV10Version,
               digest.version > known,
               digest.lastUpdateSource == "auto"
            {
                profileUpdatedNotice = "I updated your health profile based on this chat."
                analytics.track(
                    "v10_edited",
                    properties: [
                        "source": "auto",
                        "version": String(digest.version)
                    ]
                )
            }
            knownV10Version = digest.version
        } catch {
            // V10 refresh failure is non-blocking for chat UX.
        }
    }

    private func primeKnownV10VersionIfNeeded() async {
        guard knownV10Version == nil else { return }
        do {
            let digest = try await apiService.fetchV10()
            knownV10Version = digest.version
        } catch {
            // Non-blocking for chat UX.
        }
    }
}
