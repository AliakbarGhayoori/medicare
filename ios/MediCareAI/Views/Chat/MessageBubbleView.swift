import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let onCitationTap: (Citation) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 7) {
            senderRow

            Text(message.content)
                .font(.callout)
                .foregroundStyle(message.role == .user ? Color.white : Color.mcTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(bubbleFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bubbleBorder, lineWidth: message.role == .assistant ? 1 : 0)
                )
                .shadow(
                    color: Color.black.opacity(message.role == .assistant ? 0.04 : 0.12),
                    radius: message.role == .assistant ? 6 : 10,
                    x: 0,
                    y: 2
                )
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.82,
                    alignment: message.role == .user ? .trailing : .leading
                )
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .accessibilityLabel(message.role == .user ? "Your message" : "Assistant message")
                .accessibilityValue(message.content)

            if !message.citations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.citations) { citation in
                            CitationBadgeView(citation: citation) {
                                onCitationTap(citation)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            }

            if message.role == .assistant, let confidence = message.confidence {
                HStack(spacing: 6) {
                    Image(systemName: confidenceIcon(for: confidence))
                        .font(.footnote)
                    Text(confidenceText(for: confidence))
                        .font(.footnote)
                }
                .foregroundStyle(confidenceColor(for: confidence))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(confidenceColor(for: confidence).opacity(0.12))
                )
                .padding(.top, 4)
            }

            Text(DateFormatting.messageTimestamp.string(from: message.createdAt))
                .font(.caption)
                .foregroundStyle(Color.mcTextSecondary)
        }
    }

    static func streamingPreview(text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.caption.bold())
                Text("MediCare AI")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.mcTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(text)
                .font(.callout)
                .foregroundStyle(Color.mcTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.mcAssistantBubble)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.mcDivider.opacity(0.6), lineWidth: 1)
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.82, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func confidenceIcon(for confidence: String) -> String {
        switch confidence.lowercased() {
        case "high":
            return "checkmark.shield.fill"
        case "medium":
            return "info.circle"
        default:
            return "exclamationmark.triangle"
        }
    }

    private func confidenceColor(for confidence: String) -> Color {
        switch confidence.lowercased() {
        case "high":
            return .mcSuccessGreen
        case "medium":
            return .mcTextSecondary
        default:
            return .mcWarningAmber
        }
    }

    private func confidenceText(for confidence: String) -> String {
        switch confidence.lowercased() {
        case "high":
            return "Strong supporting evidence"
        case "medium":
            return "Based on the evidence available"
        default:
            return "Preliminary guidance; consider follow-up if symptoms continue"
        }
    }

    @ViewBuilder
    private var senderRow: some View {
        HStack(spacing: 6) {
            if message.role == .assistant {
                Image(systemName: "stethoscope")
                    .font(.caption.bold())
            } else {
                Image(systemName: "person.fill")
                    .font(.caption.bold())
            }

            Text(message.role == .assistant ? "MediCare AI" : "You")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.mcTextSecondary)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var bubbleFill: AnyShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.mcUserBubble.opacity(0.94),
                        Color.mcAccent
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.mcAssistantBubble)
    }

    private var bubbleBorder: Color {
        message.role == .assistant ? Color.mcDivider.opacity(0.65) : Color.clear
    }
}
