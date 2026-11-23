import Foundation

/// The health profile text split into the sections shown on the My health screen.
///
/// A line is a heading when it is a known section name ("Medications:", "**Conditions**",
/// "## Allergies"), or any short label with nothing after it ("Tilstande:"). A line such as
/// "Metformin dosage: 500 mg" is a fact, not a heading, and is shown as written.
enum HealthProfileSections {
    enum Kind: String, Equatable {
        case about, conditions, medicines, allergies, concerns, history, other
    }

    struct Section: Equatable, Identifiable {
        let kind: Kind
        let title: String
        var items: [String]

        /// Sections with the same title are merged, so the title is unique.
        var id: String { title }
    }

    /// Section names the app knows, in English, as the profile updater writes them.
    private static let knownLabels: [String: Kind] = {
        var labels: [String: Kind] = [:]
        let groups: [(Kind, [String])] = [
            (.about, ["age", "age/demographics", "demographics", "about", "about you", "about me", "personal",
                      "personal details", "personal information", "background"]),
            (.conditions, ["conditions", "condition", "medical conditions", "health conditions", "chronic conditions",
                           "diagnoses", "diagnosis"]),
            (.medicines, ["medications", "medication", "medicines", "medicine", "current medications",
                          "current medicines", "prescriptions"]),
            (.allergies, ["allergies", "allergy", "drug allergies", "known allergies"]),
            (.concerns, ["recent concerns", "concerns", "current concerns", "symptoms", "recent symptoms"]),
            (.history, ["history", "relevant history", "medical history", "past medical history", "health history"]),
        ]
        for (kind, names) in groups {
            for name in names { labels[name] = kind }
        }
        return labels
    }()

    static func parse(_ digest: String) -> [Section] {
        var sections: [Section] = []
        var current: Int?

        func start(kind: Kind, title: String) {
            if let index = sections.firstIndex(where: { $0.title == title }) {
                current = index
            } else {
                sections.append(Section(kind: kind, title: title, items: []))
                current = sections.count - 1
            }
        }

        func append(_ item: String) {
            let trimmed = item.replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            if current == nil { start(kind: .other, title: "Notes") }
            if let current { sections[current].items.append(trimmed) }
        }

        for rawLine in digest.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let found = heading(in: line) {
                start(kind: found.kind, title: found.title)
                append(found.rest)
                continue
            }
            append(bulletText(line) ?? line)
        }

        return sections.filter { !$0.items.isEmpty }
    }

    private static func heading(in line: String) -> (kind: Kind, title: String, rest: String)? {
        guard bulletText(line) == nil else { return nil }
        var text = line
        while text.hasPrefix("#") { text.removeFirst() }
        let isMarkdownHeading = text.count != line.count
        let isBold = isWrapped(text, in: "**") || isWrapped(text, in: "__")
        text = clean(text)

        var label = text
        var rest = ""
        if let colon = text.firstIndex(of: ":") {
            label = clean(String(text[..<colon]))
            rest = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        } else if !(isMarkdownHeading || isBold) {
            return nil
        }
        guard !label.isEmpty, label.count <= 40 else { return nil }

        if let kind = knownLabels[label.lowercased()] {
            return (kind, title(for: kind), rest)
        }
        // Any other label starts a section only when nothing follows it on the line.
        guard rest.isEmpty else { return nil }
        return (kind(for: label), label.prefix(1).uppercased() + label.dropFirst(), "")
    }

    /// The icon and colour for a section the app has no fixed title for.
    private static func kind(for label: String) -> Kind {
        let key = label.lowercased()
        let words = Set(key.split { !$0.isLetter }.map(String.init))
        if key.contains("allerg") { return .allergies }
        if key.contains("medic") || key.contains("drug") || key.contains("prescription")
            || key.contains("supplement") { return .medicines }
        if key.contains("condition") || key.contains("diagnos") { return .conditions }
        if key.contains("concern") || key.contains("symptom") || key.contains("recent") { return .concerns }
        if key.contains("history") || key.contains("surger") || key.contains("family") { return .history }
        if words.contains("age") || key.contains("demograph") || key.contains("about")
            || key.contains("personal") { return .about }
        return .other
    }

    private static func title(for kind: Kind) -> String {
        switch kind {
        case .about: return "About you"
        case .conditions: return "Conditions"
        case .medicines: return "Medicines"
        case .allergies: return "Allergies"
        case .concerns: return "Recent concerns"
        case .history: return "History"
        case .other: return "Notes"
        }
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "*_` \t"))
    }

    private static func isWrapped(_ text: String, in marker: String) -> Bool {
        text.count > marker.count * 2 && text.hasPrefix(marker) && text.hasSuffix(marker)
    }

    private static func bulletText(_ line: String) -> String? {
        for marker in ["- ", "* ", "• ", "– "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }
}
