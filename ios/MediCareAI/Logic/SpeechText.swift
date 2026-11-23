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
        return parts.map(clean).filter { !$0.isEmpty }.map(endSentence).joined(separator: " ")
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
