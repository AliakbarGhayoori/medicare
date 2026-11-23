import Foundation

/// One readable line for a chat in a list, taken from the stored start of its last answer.
enum ChatPreview {
    /// The server keeps the first 100 characters of the last answer.
    static let storedLength = 100

    static func text(_ lastMessage: String) -> String {
        let layout = AnswerLayout.parse(lastMessage)
        guard let first = layout.lead ?? layout.paragraphs.first ?? layout.doThis.first ?? layout.watchFor.first else {
            return ""
        }
        let line = SpeechText.clean(first)
        let wasCut = layout.unitCount == 1 && lastMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= storedLength
        return wasCut ? line + "…" : line
    }
}
