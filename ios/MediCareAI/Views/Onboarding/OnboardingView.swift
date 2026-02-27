import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var context: AppContext

    @AppStorage("mc.onboarding.page") private var page = 0
    @AppStorage("mc.onboarding.acceptedDisclaimer") private var acceptedDisclaimer = false
    @State private var startedAt = Date()

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("stethoscope", "Health Answers You Can Trust", "Ask a health question and get clear answers with sources."),
        ("heart.text.square", "Personalized for You", "Share your health details so answers fit your situation."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingCard(
                        icon: pages[index].icon,
                        title: pages[index].title,
                        subtitle: pages[index].subtitle
                    )
                    .tag(index)
                }

                DisclaimerView(acceptedDisclaimer: $acceptedDisclaimer)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.mcAccent : Color.mcDivider)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 8)

            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                    return
                }

                guard acceptedDisclaimer else { return }
                let duration = Int(Date().timeIntervalSince(startedAt))
                context.analyticsService.track(
                    "onboarding_completed",
                    properties: ["durationSeconds": String(duration)]
                )
                page = 0
                acceptedDisclaimer = false
                context.hasCompletedOnboarding = true
            } label: {
                Text(page == 2 ? "I understand and agree" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcAccent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(page == 2 && !acceptedDisclaimer)
        }
        .background(Color.mcBackground)
        .onAppear {
            startedAt = Date()
        }
    }

    private func onboardingCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(Color.mcAccent)
                .padding(.bottom, 8)
            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.mcTextPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.mcTextSecondary)
            Spacer()
        }
        .padding(24)
    }
}
