import SwiftUI

/// A finished answer: where it comes from, the short answer, the explanation and the
/// "Do this" / "Watch for" boxes. Emergencies start with the red call card.
struct AnswerView: View {
    let message: Message
    let onCitation: (Citation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if message.requiresEmergencyCare {
                EmergencyCard(
                    number: EmergencyNumber.current,
                    countryName: EmergencyNumber.countryPhrase(forRegion: EmergencyNumber.currentRegion)
                )
                AnswerBody(layout: AnswerLayout.parse(message.content), onCite: openCitation)
                if !message.citations.isEmpty {
                    SourcesRow(citations: message.citations, onCitation: onCitation)
                }
            } else {
                SourcesRow(citations: message.citations, onCitation: onCitation)
                AnswerBody(layout: AnswerLayout.parse(message.content), onCite: openCitation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func openCitation(_ number: Int) {
        if let citation = message.citations.first(where: { $0.number == number }) {
            onCitation(citation)
        }
    }
}

/// A finished answer only changes with its message, so streaming a new answer doesn't
/// redraw (and re-parse) the earlier ones.
extension AnswerView: Equatable {
    nonisolated static func == (lhs: AnswerView, rhs: AnswerView) -> Bool {
        lhs.message == rhs.message
    }
}

/// The heartbeat mark with "From 3 trusted sources" and a chip per source.
struct SourcesRow: View {
    let citations: [Citation]
    let onCitation: (Citation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PulseMark()
                if !citations.isEmpty {
                    Text(citations.count == 1 ? "From 1 trusted source" : "From \(citations.count) trusted sources")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mcInk2)
                }
            }
            .accessibilityElement(children: .combine)

            if !citations.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(citations) { citation in
                        SourceChip(citation: citation) { onCitation(citation) }
                    }
                }
            }
        }
    }
}

/// The text of an answer in reading order. Also used while an answer streams in.
struct AnswerBody: View {
    let layout: AnswerLayout
    let onCite: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lead = layout.lead {
                AnswerText(text: lead, font: .title3.weight(.semibold), onCite: onCite)
                    .accessibilityIdentifier("answer.lead")
            }
            ForEach(Array(layout.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                AnswerText(text: paragraph, onCite: onCite)
            }
            if !layout.doThis.isEmpty {
                CalloutBox(kind: .doThis, items: layout.doThis, onCite: onCite)
                    .accessibilityIdentifier("answer.doThis")
                    .padding(.top, 4)
            }
            if !layout.watchFor.isEmpty {
                CalloutBox(kind: .watchFor, items: layout.watchFor, onCite: onCite)
                    .accessibilityIdentifier("answer.watchFor")
            }
            ForEach(Array(layout.closing.enumerated()), id: \.offset) { _, paragraph in
                AnswerText(text: paragraph, onCite: onCite)
            }
        }
    }
}
