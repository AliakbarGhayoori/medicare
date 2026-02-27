import Foundation

enum ChatStreamEvent {
    case token(String)
    case searching(tool: String)
    case done(ChatDonePayload)
    case error(APIError)
}

struct ChatDonePayload: Codable {
    let messageId: String
    let conversationId: String
    let content: String?
    let citations: [Citation]
    let confidence: String
    let requiresEmergencyCare: Bool
}
