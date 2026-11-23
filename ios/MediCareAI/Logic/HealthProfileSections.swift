import Foundation

/// The health profile text split into the sections shown on the My health screen.
enum HealthProfileSections {
    enum Kind: String, Equatable {
        case about, conditions, medicines, allergies, concerns, history, other
    }

    struct Section: Equatable, Identifiable {
        let kind: Kind
        let title: String
        var items: [String]

        var id: String { "\(kind.rawValue)-\(title)" }
    }

    static func parse(_ digest: String) -> [Section] {
        var sections: [Section] = []
        var loose: [String] = []

        func append(_ item: String) {
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            if sections.isEmpty {
                loose.append(trimmed)
            } else {
                sections[sections.count - 1].items.append(trimmed)
            }
        }

        for rawLine in digest.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let found = heading(in: line) {
                sections.append(Section(kind: found.kind, title: found.title, items: []))
                append(found.rest)
                continue
            }
            append(bulletText(line) ?? line)
        }

        if !loose.isEmpty {
            sections.insert(Section(kind: .other, title: "Notes", items: loose), at: 0)
        }
        return sections.filter { !$0.items.isEmpty }
    }

    private static func heading(in line: String) -> (kind: Kind, title: String, rest: String)? {
        var text = line
        while text.hasPrefix("#") { text.removeFirst() }
        let markdownHeading = text.count != line.count
        text = text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
        if bulletText(line) != nil { return nil }

        var label = text
        var rest = ""
        if let colon = text.firstIndex(of: ":") {
            label = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
            rest = String(text[text.index(after: colon)...])
        } else if !markdownHeading {
            return nil
        }
        guard !label.isEmpty, label.count <= 40 else { return nil }

        let detected = kind(for: label)
        // An unknown label only starts a section when nothing follows it on the line.
        if detected == .other, !rest.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        return (detected, title(for: detected, label: label), rest)
    }

    private static func kind(for label: String) -> Kind {
        let key = label.lowercased()
        if key.contains("allerg") { return .allergies }
        if key.contains("medic") || key.contains("drug") || key.contains("prescription")
            || key.contains("supplement") { return .medicines }
        if key.contains("condition") || key.contains("diagnos") { return .conditions }
        if key.contains("concern") || key.contains("symptom") || key.contains("recent") { return .concerns }
        if key.contains("history") || key.contains("surger") || key.contains("family") { return .history }
        if key.contains("age") || key.contains("demograph") || key.contains("about")
            || key.contains("personal") { return .about }
        return .other
    }

    private static func title(for kind: Kind, label: String) -> String {
        switch kind {
        case .about: return "About you"
        case .conditions: return "Conditions"
        case .medicines: return "Medicines"
        case .allergies: return "Allergies"
        case .concerns: return "Recent concerns"
        case .history: return "History"
        case .other: return label.prefix(1).uppercased() + label.dropFirst()
        }
    }

    private static func bulletText(_ line: String) -> String? {
        for marker in ["- ", "* ", "• ", "– "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }
}
