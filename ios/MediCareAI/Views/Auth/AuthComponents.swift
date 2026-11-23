import SwiftUI

/// The top of the sign-in screens: the heartbeat mark and a serif title.
struct AuthHeader: View {
    let title: String
    var subtitle: String?
    var showsMark = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsMark {
                HeartbeatLine(variant: .mark, lineWidth: 4, drawsIn: true)
                    .frame(width: 84, height: 44)
                    .padding(.bottom, 6)
            }
            Text(title)
                .font(.mcDisplay(40, relativeTo: .largeTitle))
                .foregroundStyle(Color.mcInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labelled field on a white rounded background.
struct FormField<Field: View>: View {
    let label: String
    var note: String?
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mcInk)
                .accessibilityHidden(true)
            field
                .font(.body)
                .foregroundStyle(Color.mcInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.mcLine, lineWidth: 1)
                )
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A short message under a form: a problem in amber, or a success in green.
struct FormMessage: View {
    enum Kind { case problem, success }

    let text: String
    var kind: Kind = .problem

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Color.mcInk)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: kind == .problem ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(kind == .problem ? Color.mcAmber : Color.mcGreen)
        }
        .font(.subheadline)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            kind == .problem ? Color.mcAmberTint : Color.mcGreenTint,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

/// An icon tile with a title and a line of detail, used on the welcome pages.
struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: symbol, color: tint, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.mcInk)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.mcInk2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

enum UITesting {
    /// Password autofill prompts get in the way of UI tests.
    static let isActive = ProcessInfo.processInfo.arguments.contains("--uitesting")
}

enum AuthCopy {
    /// Passed as a plain String: a string literal is read as markdown, and SwiftUI would draw
    /// the address as a blue link in the empty field.
    static let emailExample: String = "you@example.com"
}
