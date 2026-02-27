import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let lastMessage: String
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct ConversationListResponse: Codable {
    let conversations: [Conversation]
    let hasMore: Bool
    let nextCursor: String?
}

struct ConversationMessagesResponse: Codable {
    let conversationId: String
    let messages: [Message]
    let hasMore: Bool
    let nextCursor: String?
}
