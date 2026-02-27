import SwiftUI

struct EmptyChatView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    let onSuggestionTap: (String) -> Void

    private let suggestions = [
        "What are common side effects of metformin?",
        "I have had headaches for 3 days. What could be causing them?",
        "Is it safe to take ibuprofen with blood pressure medication?"
    ]

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.mcAccent.opacity(0.15))
                        .frame(width: 74, height: 74)
                    Image(systemName: "stethoscope")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(Color.mcAccent)
                }

                Text(greeting)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mcTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Ask any health question. I will check reliable sources and explain things clearly.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.mcBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.mcInputBorder.opacity(0.8), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    capabilityChip(icon: "doc.text.magnifyingglass", text: "Checks trusted sources")
                    capabilityChip(icon: "book.closed.fill", text: "Cites evidence")
                    capabilityChip(icon: "cross.case.fill", text: "Flags emergencies")
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
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
                        .padding(.vertical, 14)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.mcBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.mcInputBorder, lineWidth: 1)
                        )
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
            return "Hi, \(name). What do you want to check today?"
        }
        return "Hi there. What do you want to check today?"
    }

    @ViewBuilder
    private func capabilityChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(Color.mcTextSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.mcBackgroundSecondary)
        )
    }
}
