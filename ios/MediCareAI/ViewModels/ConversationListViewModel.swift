import Foundation
import Combine

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false

    private let apiService: APIServicing
    private let analytics: AnalyticsServicing
    private var nextCursor: String?
    /// Goes up on every reset, so a request that was still running for the old account
    /// can't bring its chats back.
    private var generation = 0

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    /// Forgets the signed-out account's chats.
    func reset() {
        generation += 1
        conversations = []
        hasMore = false
        nextCursor = nil
        errorMessage = nil
        isLoading = false
    }

    func loadInitial() async {
        let started = generation
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchHistory(limit: 20, before: nil)
            guard started == generation else { return }
            conversations = response.conversations
            hasMore = response.hasMore
            nextCursor = response.nextCursor
            analytics.track(
                "history_loaded",
                properties: ["count": String(response.conversations.count)]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }

        isLoading = false
    }

    func loadMoreIfNeeded(current conversation: Conversation) async {
        guard hasMore, !isLoading, conversations.last?.id == conversation.id else {
            return
        }

        let started = generation
        isLoading = true

        do {
            let response = try await apiService.fetchHistory(limit: 20, before: nextCursor)
            guard started == generation else { return }
            conversations.append(contentsOf: response.conversations)
            hasMore = response.hasMore
            nextCursor = response.nextCursor
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }
        isLoading = false
    }
}
