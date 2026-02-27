import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String

    let isDisabled: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.mcDivider)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Type your health question...", text: $text, axis: .vertical)
                    .font(.callout)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.mcInputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.mcInputBorder, lineWidth: 1)
                    )
                    .accessibilityLabel("Health question text field")
                    .accessibilityIdentifier("chat.input")

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(canSend ? Color.white : Color.mcTextSecondary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(canSend ? Color.mcAccent : Color.mcDivider)
                        )
                }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!canSend)
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends your health question")
                .accessibilityIdentifier("chat.send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.mcBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color.mcBackground.opacity(0.92))
        }
    }

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
