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

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    func loadInitial() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchHistory(limit: 20, before: nil)
            conversations = response.conversations
            hasMore = response.hasMore
            nextCursor = response.nextCursor
            analytics.track(
                "history_loaded",
                properties: ["count": String(response.conversations.count)]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }

        isLoading = false
    }

    func loadMoreIfNeeded(current conversation: Conversation) async {
        guard hasMore, !isLoading, conversations.last?.id == conversation.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apiService.fetchHistory(limit: 20, before: nextCursor)
            conversations.append(contentsOf: response.conversations)
            hasMore = response.hasMore
            nextCursor = response.nextCursor
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }
}
