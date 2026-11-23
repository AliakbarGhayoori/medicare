import SwiftUI

/// The question field with a microphone (when empty) or a send button (when there is text).
struct Composer: View {
    @Binding var text: String
    var placeholder: String
    /// An answer is still arriving; sending waits until it is done.
    var isBusy: Bool
    var isListening: Bool
    var focus: FocusState<Bool>.Binding
    /// "chat" gives the identifiers chat.input, chat.send and chat.mic.
    var idPrefix = "chat"
    /// A white field with a soft shadow, for the paper background on Home.
    var raised = false
    let onSend: () -> Void
    let onMic: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 48

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.body)
                .foregroundStyle(Color.mcInk)
                .lineLimit(1...6)
                .focused(focus)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: buttonSize)
                .background(
                    raised ? Color.mcSurface : Color.mcField,
                    in: RoundedRectangle(cornerRadius: buttonSize / 2, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: buttonSize / 2, style: .continuous)
                        .strokeBorder(Color.mcLine, lineWidth: raised ? 0.5 : 1)
                )
                .shadow(color: Color.mcInk.opacity(raised ? 0.12 : 0), radius: 12, y: 6)
                .accessibilityIdentifier("\(idPrefix).input")

            if hasText && !isListening {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.mcBlue.opacity(isBusy ? 0.4 : 1), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel("Send")
                .accessibilityHint(isBusy ? "Wait for the answer to finish" : "Sends your question")
                .accessibilityIdentifier("\(idPrefix).send")
            } else {
                MicButton(isListening: isListening, size: buttonSize, identifier: "\(idPrefix).mic", action: onMic)
            }
        }
    }
}

/// Starts and stops talking instead of typing.
struct MicButton: View {
    let isListening: Bool
    let size: CGFloat
    var identifier = "chat.mic"
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isListening && !reduceMotion {
                    Circle()
                        .stroke(Color.mcBlue.opacity(0.35), lineWidth: 3)
                        .scaleEffect(pulse ? 1.25 : 1)
                        .opacity(pulse ? 0 : 1)
                }
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.mcBlue, in: Circle())
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Stop listening" : "Ask by talking")
        .accessibilityIdentifier(identifier)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: isListening) { _, _ in startPulseIfNeeded() }
    }

    private func startPulseIfNeeded() {
        guard isListening, !reduceMotion else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}
