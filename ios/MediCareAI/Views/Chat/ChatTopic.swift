import SwiftUI

/// A Home topic. It opens a new chat with example questions; nothing is sent until the
/// person sends it.
struct ChatTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let intro: String
    let placeholder: String
    let examples: [String]

    static func == (lhs: ChatTopic, rhs: ChatTopic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let symptom = ChatTopic(
        id: "symptom",
        title: "A symptom",
        systemImage: "thermometer.medium",
        tint: .tileBlue,
        intro: "Tell me what you feel, when it started and how strong it is.",
        placeholder: "Describe what you feel",
        examples: [
            "I have had a headache for three days. What should I do?",
            "My ankles swell in the evening. Should I worry?",
            "I feel dizzy when I stand up. Why does that happen?",
        ]
    )

    static let medicines = ChatTopic(
        id: "medicines",
        title: "My medicines",
        systemImage: "pills.fill",
        tint: .tileTeal,
        intro: "Ask about a medicine, a side effect or what you can take together.",
        placeholder: "Ask about a medicine",
        examples: [
            "Is coffee okay with metformin in the morning?",
            "Can I take ibuprofen with my blood pressure tablets?",
            "What should I do if I forget a dose?",
        ]
    )

    static let testResult = ChatTopic(
        id: "testResult",
        title: "A test result",
        systemImage: "doc.text.magnifyingglass",
        tint: .tileViolet,
        intro: "Type the test name and your number, and I will explain what it means.",
        placeholder: "Type the test and your result",
        examples: [
            "What does an HbA1c of 7.2% mean?",
            "My cholesterol is 6.1 mmol/L. Is that high?",
            "What is a healthy blood pressure at my age?",
        ]
    )

    static let foodAndExercise = ChatTopic(
        id: "foodAndExercise",
        title: "Food and exercise",
        systemImage: "leaf.fill",
        tint: .tileGreen,
        intro: "Ask what to eat, how to stay active and what is safe for you.",
        placeholder: "Ask about food or exercise",
        examples: [
            "What is a good breakfast if I have diabetes?",
            "How much should I walk each day at 75?",
            "Which exercises help with knee pain?",
        ]
    )

    static let all: [ChatTopic] = [.symptom, .medicines, .testResult, .foodAndExercise]

    /// Examples for a new chat that did not start from a topic.
    static let general = ChatTopic(
        id: "general",
        title: "New chat",
        systemImage: "bubble.left.and.bubble.right.fill",
        tint: .tileBlue,
        intro: "Ask me anything about your health. I check trusted sources and name them.",
        placeholder: "Ask a health question",
        examples: [
            "Is coffee okay with metformin in the morning?",
            "I feel dizzy when I stand up. Why does that happen?",
            "How much should I walk each day at 75?",
        ]
    )
}

/// How a new chat begins.
enum ChatStarter: Hashable {
    /// Shows the topic's examples; nothing is sent.
    case topic(ChatTopic)
    /// A question the person already sent from Home; it is asked straight away.
    case question(String)
}

/// One push onto the chat screen.
struct ChatRoute: Identifiable, Hashable {
    let id = UUID()
    var conversation: Conversation?
    var starter: ChatStarter?
}
