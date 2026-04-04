import SwiftUI

struct EmptyChatView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    let onSuggestionTap: (String) -> Void

    private let suggestions = [
        "I've been having headaches for a few days. What could be going on?",
        "Can you check if my medications have any interactions?",
        "What exercises would be good for someone with my health profile?"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            VStack(spacing: 14) {
                Image("empty-chat")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 140, maxHeight: 140)
                    .accessibilityHidden(true)

                Text(greeting)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mcTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Ask me anything about your health.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color.mcBackgroundSecondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSuggestionTap(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "text.bubble.fill")
                                .font(.callout)
                                .foregroundStyle(Color.mcAccent)
                                .frame(width: 22)

                            Text(suggestion)
                                .font(.callout)
                                .foregroundStyle(Color.mcTextPrimary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, 14)
                        .background(Color.mcBackgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use suggested question: \(suggestion)")
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var greeting: String {
        if let email = authViewModel.state == .authenticated ? authViewModel.currentEmail : nil {
            let name = email.components(separatedBy: "@").first?.capitalized ?? "there"
            return "Hi \(name), what can I help with?"
        }
        return "Hi there, what can I help with?"
    }
}
