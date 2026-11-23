import Foundation

/// The parts of an assistant answer in reading order: a one-line short answer,
/// the explanation, and the "Do this" and "Watch for" lists.
///
/// Works on any answer text: the sectioned layout the app asks for, older answers
/// with a "What to do next" list, and partial text while an answer is streaming.
struct AnswerLayout: Equatable {
    var lead: String?
    var paragraphs: [String]
    var doThis: [String]
    var watchFor: [String]
    /// Text after the "Do this" and "Watch for" lists, such as a closing question.
    var closing: [String] = []

    var isEmpty: Bool {
        lead == nil && paragraphs.isEmpty && doThis.isEmpty && watchFor.isEmpty
    }

    /// Number of separate pieces of text; never shrinks while an answer streams in.
    var unitCount: Int {
        (lead == nil ? 0 : 1) + paragraphs.count + doThis.count + watchFor.count
    }

    /// Longest line that can be shown as the short answer at the top.
    static let maxLeadLength = 160

    private enum Part { case body, doThis, watchFor }

    private static let doThisHeadings = [
        "do this", "what to do", "what to do next", "what you can do", "what you can do now", "next steps",
    ]
    private static let watchForHeadings = [
        "watch for", "when to get help", "get help if", "warning signs", "when to see a doctor",
        "seek help if", "seek medical help if",
    ]

    /// - Parameter isPartial: true while the answer is still streaming. A last line that could
    ///   still become a heading or a list item is held back, so the layout doesn't jump.
    static func parse(_ text: String, isPartial: Bool = false) -> AnswerLayout {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if isPartial, let last = lines.last, isIncomplete(last) {
            lines.removeLast()
        }

        var part = Part.body
        var body: [String] = []
        var doThis: [String] = []
        var watchFor: [String] = []

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            switch part {
            case .body: body.append(trimmed)
            case .doThis: doThis.append(trimmed)
            case .watchFor: watchFor.append(trimmed)
            }
        }

        for line in lines where !line.isEmpty {
            if let found = heading(in: line) {
                part = found.part
                add(found.rest)
                continue
            }
            if let item = bulletText(line) {
                guard !item.isEmpty else { continue }
                add(part == .body && !isNumbered(line) ? "• " + item : (part == .body ? line : item))
                continue
            }
            add(line)
        }

        var lead: String?
        let total = body.count + doThis.count + watchFor.count
        if let first = body.first,
           first.count <= maxLeadLength,
           !first.hasPrefix("• "),
           !isNumbered(first),
           !first.hasSuffix(":"),
           isPartial || total > 1 {
            lead = first
            body.removeFirst()
        }
        return AnswerLayout(lead: lead, paragraphs: body, doThis: doThis, watchFor: watchFor)
    }

    private static func heading(in line: String) -> (part: Part, rest: String)? {
        var label = line
        while label.hasPrefix("#") { label.removeFirst() }
        label = label.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
        var rest = ""
        if let colon = label.firstIndex(of: ":") {
            rest = String(label[label.index(after: colon)...])
            label = String(label[..<colon])
        }
        let key = label.trimmingCharacters(in: .whitespaces).lowercased()
        if doThisHeadings.contains(key) { return (.doThis, rest) }
        if watchForHeadings.contains(key) { return (.watchFor, rest) }
        return nil
    }

    private static func bulletText(_ line: String) -> String? {
        for marker in ["- ", "* ", "• ", "– ", "— "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        if ["-", "*", "•", "–", "—"].contains(line) { return "" }
        if isNumbered(line) {
            let digits = line.prefix { $0.isASCII && $0.isNumber }.count
            return String(line.dropFirst(digits + 2)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// "1. Step" or "2) Step".
    private static func isNumbered(_ line: String) -> Bool {
        let digits = line.prefix { $0.isASCII && $0.isNumber }.count
        guard digits > 0, digits <= 2 else { return false }
        let after = line.dropFirst(digits)
        return after.hasPrefix(". ") || after.hasPrefix(") ")
    }

    /// A trailing line that may still turn into a heading or a list item.
    private static func isIncomplete(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        if ["-", "*", "•", "–", "—", "**", "__"].contains(line) { return true }
        if line.allSatisfy({ $0 == "#" }) { return true }
        if line.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." || $0 == ")" }) { return true }
        var label = line
        while label.hasPrefix("#") { label.removeFirst() }
        label = label.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !label.isEmpty else { return true }
        return (doThisHeadings + watchForHeadings).contains { $0.hasPrefix(label) && $0 != label }
    }
}
