import Foundation

/// Answer text prepared for reading aloud: no source numbers, markdown or list markers.
enum SpeechText {
    static func plain(from answer: String) -> String {
        let layout = AnswerLayout.parse(answer)
        var parts: [String] = []
        if let lead = layout.lead { parts.append(lead) }
        parts.append(contentsOf: layout.paragraphs)
        if !layout.doThis.isEmpty {
            parts.append("Do this.")
            parts.append(contentsOf: layout.doThis)
        }
        if !layout.watchFor.isEmpty {
            parts.append("Watch for.")
            parts.append(contentsOf: layout.watchFor)
        }
        parts.append(contentsOf: layout.closing)
        return parts.map(clean).filter { !$0.isEmpty }.map(endSentence).joined(separator: " ")
    }

    /// What the red emergency card says, for Listen and VoiceOver.
    static func emergencyIntro(number: String) -> String {
        "This could be an emergency. Call \(number) now. Don't wait to see if it gets better."
    }

    /// The text Listen reads for an answer: the emergency card first, when there is one.
    static func forMessage(_ message: Message, emergencyNumber: String) -> String {
        let answer = plain(from: message.content)
        guard message.requiresEmergencyCare else { return answer }
        let intro = emergencyIntro(number: emergencyNumber)
        return answer.isEmpty ? intro : intro + " " + answer
    }

    static func clean(_ text: String) -> String {
        var result = CitationText.plain(text)
        if let link = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]*\)"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = link.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }
        for marker in ["**", "__", "`"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        if result.hasPrefix("• ") { result.removeFirst(2) }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func endSentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?:".contains(last) ? text : text + "."
    }
}
