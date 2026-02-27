import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let role: MessageRole
    let content: String
    let citations: [Citation]
    let confidence: String?
    let requiresEmergencyCare: Bool
    let createdAt: Date

    enum MessageRole: String, Codable {
        case user
        case assistant
    }
}

struct Citation: Identifiable, Codable, Equatable {
    let number: Int
    let title: String
    let source: String
    let url: String
    let snippet: String

    var id: Int { number }
}
