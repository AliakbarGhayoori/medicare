import Foundation

/// Splits the numbered source markers ("[1]", "[1, 2]") out of answer text so they can be
/// drawn as tappable source numbers.
enum CitationText {
    enum Segment: Equatable {
        case text(String)
        case cite(Int)
    }

    static func segments(_ text: String) -> [Segment] {
        var result: [Segment] = []
        var buffer = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "[",
               let numbers = citationNumbers(in: text, from: index) {
                if buffer.hasSuffix(" ") { buffer.removeLast() }
                if !buffer.isEmpty {
                    result.append(.text(buffer))
                    buffer = ""
                }
                result.append(contentsOf: numbers.values.map { Segment.cite($0) })
                index = numbers.end
                continue
            }
            buffer.append(text[index])
            index = text.index(after: index)
        }
        if !buffer.isEmpty { result.append(.text(buffer)) }
        return result
    }

    /// The text without its source markers.
    static func plain(_ text: String) -> String {
        segments(text).map { segment -> String in
            if case .text(let value) = segment { return value }
            return ""
        }.joined()
    }

    private static func citationNumbers(
        in text: String,
        from open: String.Index
    ) -> (values: [Int], end: String.Index)? {
        let limit = text.index(open, offsetBy: 16, limitedBy: text.endIndex) ?? text.endIndex
        guard let close = text[open..<limit].firstIndex(of: "]") else { return nil }
        let inner = text[text.index(after: open)..<close]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap { Int($0) }
        guard !parts.isEmpty, numbers.count == parts.count,
              numbers.allSatisfy({ $0 > 0 && $0 < 100 }) else { return nil }
        return (numbers, text.index(after: close))
    }
}
