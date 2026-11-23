import SwiftUI

// MARK: - Buttons

/// The main action: white text on a blue (or red, for emergencies) capsule.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = .mcBlue
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4), in: Capsule())
            .contentShape(Capsule())
    }
}

/// A quieter action: ink text on a surface capsule with a hairline.
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = .mcInk
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint.opacity(isEnabled ? 1 : 0.4))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.mcSurface.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.mcLine, lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - Surfaces

extension View {
    /// A white (dark: navy) card with continuous corners and a hairline.
    func mcCard(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.mcLine.opacity(0.7), lineWidth: 0.5)
            )
    }

    /// The bright paper background behind a whole screen.
    func mcScreenBackground(_ color: Color = .mcPaper) -> some View {
        self.background(color.ignoresSafeArea())
    }
}

/// A Settings-style coloured square with a white SF Symbol.
struct IconTile: View {
    let systemName: String
    let color: Color
    @ScaledMetric private var size: CGFloat

    init(systemName: String, color: Color, size: CGFloat = 30) {
        self.systemName = systemName
        self.color = color
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A section heading inside a screen.
struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.mcInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Sources

/// A filled blue circle with a source number.
struct CiteBadge: View {
    let number: Int
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 20

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.mcBlue, in: Circle())
            .accessibilityHidden(true)
    }
}

/// "1 Mayo Clinic": a tappable source under an answer.
struct SourceChip: View {
    let citation: Citation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CiteBadge(number: citation.number)
                Text(SourceName.display(for: citation.source))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcInk)
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .frame(minHeight: 40)
            .background(Color.mcBlueTint, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source \(citation.number), \(SourceName.display(for: citation.source))")
        .accessibilityHint("Shows where this information comes from")
        .accessibilityIdentifier("citation.\(citation.number)")
    }
}

// MARK: - Answer text

/// Answer text with inline markdown (bold, links) and the source numbers drawn as
/// filled blue circles that open the source when tapped.
struct AnswerText: View {
    let text: String
    var font: Font = .body
    var color: Color = .mcInk
    let onCite: (Int) -> Void

    var body: some View {
        Text(AnswerText.attributed(text))
            .font(font)
            .foregroundStyle(color)
            .tint(Color.mcBlueText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == AnswerText.citeScheme, let number = Int(url.host ?? "") {
                    onCite(number)
                    return .handled
                }
                return .systemAction
            })
            .accessibilityLabel(AnswerText.spoken(text))
    }

    static let citeScheme = "medicare-cite"

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        for segment in CitationText.segments(text) {
            switch segment {
            case .text(let value):
                result += (try? AttributedString(markdown: value, options: options)) ?? AttributedString(value)
            case .cite(let number):
                var cite = AttributedString("\u{2009}" + circled(number))
                cite.link = URL(string: "\(citeScheme)://\(number)")
                cite.foregroundColor = .mcBlueText
                result += cite
            }
        }
        return result
    }

    /// ➊ to ➓ for sources 1–10, "[11]" after that.
    static func circled(_ number: Int) -> String {
        if (1...10).contains(number), let scalar = Unicode.Scalar(0x278A + number - 1) {
            return String(Character(scalar))
        }
        return "[\(number)]"
    }

    /// What VoiceOver reads: no markdown, and "source 1" instead of the circled number.
    static func spoken(_ text: String) -> String {
        CitationText.segments(text).map { segment -> String in
            switch segment {
            case .text(let value): return SpeechText.clean(value)
            case .cite(let number): return " (source \(number))"
            }
        }.joined()
    }
}

// MARK: - Do this / Watch for

struct CalloutBox: View {
    enum Kind {
        case doThis
        case watchFor
    }

    let kind: Kind
    let items: [String]
    let onCite: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(kind == .doThis ? "Do this" : "Watch for")
                    .font(.headline)
            } icon: {
                Image(systemName: kind == .doThis ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.headline)
            }
            .foregroundStyle(kind == .doThis ? Color.mcGreen : Color.mcAmber)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(kind == .doThis ? Color.mcGreen : Color.mcAmber)
                            .accessibilityHidden(true)
                        AnswerText(text: item, onCite: onCite)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            kind == .doThis ? Color.mcGreenTint : Color.mcAmberTint,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Messages

/// The person's own question, as an iMessage-style bubble on the right.
struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                Color.mcBlue,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: 20,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 20,
                    style: .continuous
                )
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You asked: \(text)")
    }
}

// MARK: - Emergency

/// The always-visible "Emergency 112" pill on Home.
struct EmergencyPill: View {
    let number: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "tel://\(number)") { openURL(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "phone.fill")
                    .font(.footnote.weight(.semibold))
                Text("Emergency \(number)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.mcRedText)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.mcRedTint, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call emergency services, \(number)")
        .accessibilityIdentifier("home.emergency")
    }
}

/// The red card shown above an answer that may be an emergency.
struct EmergencyCard: View {
    let number: String
    let countryName: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("This could be an emergency.")
                    .font(.title3.weight(.bold))
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .font(.title3.weight(.bold))
            }
            Text("Call \(number) now. Don't wait to see if it gets better.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: "tel://\(number)") { openURL(url) }
            } label: {
                Label("Call \(number)", systemImage: "phone.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.mcRed)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat.callEmergency")
            if let countryName {
                Text("The emergency number in \(countryName).")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mcRed, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
