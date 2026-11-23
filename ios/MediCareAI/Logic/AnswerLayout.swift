import Foundation

/// The parts of an assistant answer in reading order: a one-line short answer,
/// the explanation, the "Do this" and "Watch for" lists, and any text after them.
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
        lead == nil && paragraphs.isEmpty && doThis.isEmpty && watchFor.isEmpty && closing.isEmpty
    }

    /// Number of separate pieces of text; never shrinks while an answer streams in.
    var unitCount: Int {
        (lead == nil ? 0 : 1) + paragraphs.count + doThis.count + watchFor.count + closing.count
    }

    /// Longest line that can be shown as the short answer at the top.
    static let maxLeadLength = 160

    /// A line up to this long that ends with ":" reads as a heading.
    private static let maxHeadingLength = 60

    private enum Part { case body, doThis, watchFor, closing }

    private static let doThisHeadings = [
        "do this", "what to do", "what to do next", "what you can do", "what you can do now", "next steps",
    ]
    private static let watchForHeadings = [
        "watch for", "when to get help", "get help if", "warning signs", "when to see a doctor",
        "seek help if", "seek medical help if", "seek medical attention if",
        "seek immediate medical attention if", "call your doctor if", "see a doctor if", "see your doctor if",
        "red flags", "when to seek emergency care", "when to seek medical help", "when to seek medical attention",
        "get emergency help if", "go to the emergency room if", "call emergency services if",
    ]

    /// Bold, italic and code markers that can wrap a heading.
    private static let markup = CharacterSet(charactersIn: "*_` \t")
    /// What may be left after a heading's colon without being an item ("**Do this:**", "**Do this:*").
    private static let markupAndPunctuation = CharacterSet(charactersIn: "*_`.:-–— \t")

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
        var closing: [String] = []

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            switch part {
            case .body: body.append(trimmed)
            case .doThis: doThis.append(trimmed)
            case .watchFor: watchFor.append(trimmed)
            case .closing: closing.append(trimmed)
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
                switch part {
                case .doThis, .watchFor: add(item)
                case .body, .closing: add(isNumbered(line) ? line : "• " + item)
                }
                continue
            }
            // A box ends at the first line after its list, or at a heading the app doesn't know,
            // so a closing question or the crisis lines never show as steps or warning signs.
            if part == .doThis || part == .watchFor {
                let boxHasItems = part == .doThis ? !doThis.isEmpty : !watchFor.isEmpty
                if boxHasItems || looksLikeHeading(line) {
                    part = .closing
                }
            }
            add(line)
        }

        // The first line is the short answer only when more text follows it. While streaming,
        // that is true only once the next line has started, so the layout never steps back.
        var lead: String?
        let total = body.count + doThis.count + watchFor.count + closing.count
        if let first = body.first,
           total > 1,
           first.count <= maxLeadLength,
           !first.hasPrefix("• "),
           !isNumbered(first),
           !first.hasSuffix(":") {
            lead = first
            body.removeFirst()
        }
        return AnswerLayout(lead: lead, paragraphs: body, doThis: doThis, watchFor: watchFor, closing: closing)
    }

    private static func heading(in line: String) -> (part: Part, rest: String)? {
        guard bulletText(line) == nil else { return nil }
        var text = line
        while text.hasPrefix("#") { text.removeFirst() }
        text = stripMarkup(text)
        var label = text
        var rest = ""
        if let colon = text.firstIndex(of: ":") {
            label = String(text[..<colon])
            rest = String(text[text.index(after: colon)...])
        }
        if rest.trimmingCharacters(in: markupAndPunctuation).isEmpty { rest = "" }
        let key = stripMarkup(label).lowercased()
        if doThisHeadings.contains(key) { return (.doThis, rest) }
        if watchForHeadings.contains(key) { return (.watchFor, rest) }
        return nil
    }

    /// "Good to know:", "**Good to know**" or "## Good to know".
    private static func looksLikeHeading(_ line: String) -> Bool {
        if line.hasPrefix("#") { return true }
        for marker in ["**", "__"] where line.count > marker.count * 2 && line.hasPrefix(marker) && line.hasSuffix(marker) {
            return true
        }
        let plain = stripMarkup(line)
        return plain.hasSuffix(":") && plain.count <= maxHeadingLength
    }

    private static func stripMarkup(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: markup)
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
        label = stripMarkup(label).lowercased()
        guard !label.isEmpty else { return true }
        return (doThisHeadings + watchForHeadings).contains { $0.hasPrefix(label) && $0 != label }
    }
}
