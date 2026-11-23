import SwiftUI

/// "Checking trusted sources…" with the moving heartbeat while an answer is prepared.
struct ChatStatusLine: View {
    let isWriting: Bool
    var query: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HeartbeatActivity()
            VStack(alignment: .leading, spacing: 2) {
                Text(isWriting ? "Writing your answer…" : "Checking trusted sources…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcInk2)
                if !isWriting, let query, !query.isEmpty {
                    Text("Looking up \u{201C}\(query)\u{201D}")
                        .font(.footnote)
                        .foregroundStyle(Color.mcInk2)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat.status")
    }
}

/// Shown when an answer could not be finished. Anything that arrived stays above it.
struct ChatErrorCard: View {
    let title: String
    let message: String
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.mcInk)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.mcAmber)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(Color.mcInk2)
                .fixedSize(horizontal: false, vertical: true)
            if canRetry {
                Button("Try again", action: retry)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("chat.retry")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mcAmberTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// The empty chat: what to ask and a few examples. Tapping an example puts it in the field.
struct ChatWelcome: View {
    let topic: ChatTopic
    let onExample: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if topic == .general {
                    PulseMark()
                } else {
                    IconTile(systemName: topic.systemImage, color: topic.tint, size: 36)
                }
                Text(topic == .general ? "Ask a health question" : topic.title)
                    .font(.mcDisplay(30, relativeTo: .title))
                    .foregroundStyle(Color.mcInk)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(topic.intro)
                .font(.body)
                .foregroundStyle(Color.mcInk2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("For example")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcInk2)
                ForEach(topic.examples, id: \.self) { example in
                    Button {
                        onExample(example)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(example)
                                .font(.body)
                                .foregroundStyle(Color.mcInk)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "square.and.pencil")
                                .font(.body)
                                .foregroundStyle(Color.mcBlueText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .background(Color.mcBlueTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Puts this question in the box so you can change it before sending")
                }
            }

            Label {
                Text("In an emergency, call \(EmergencyNumber.current) now.")
            } icon: {
                Image(systemName: "phone.fill")
            }
            .font(.footnote)
            .foregroundStyle(Color.mcInk2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.welcome")
    }
}
