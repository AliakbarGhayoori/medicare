import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var context: AppContext

    @AppStorage("mc.onboarding.page") private var page = 0
    @AppStorage("mc.onboarding.acceptedDisclaimer") private var acceptedDisclaimer = false
    @AppStorage("mc.onboarding.acceptedDataSharing") private var acceptedDataSharing = false
    @State private var startedAt = Date()

    private let totalPages = 4

    private let introPages: [(illustration: String, title: String, subtitle: String)] = [
        ("onboarding-welcome", "Health Answers You Can Trust", "Clear, evidence-backed answers from sources you can verify."),
        ("onboarding-personalized", "Personalized for You", "The more you share, the more helpful your answers become."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<introPages.count, id: \.self) { index in
                    onboardingCard(
                        illustration: introPages[index].illustration,
                        title: introPages[index].title,
                        subtitle: introPages[index].subtitle
                    )
                    .tag(index)
                }

                DataPrivacyView(acceptedDataSharing: $acceptedDataSharing)
                    .tag(2)

                DisclaimerView(acceptedDisclaimer: $acceptedDisclaimer)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.mcAccent : Color.mcDivider)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 8)

            Button {
                if page < totalPages - 1 {
                    withAnimation { page += 1 }
                    return
                }

                guard acceptedDisclaimer && acceptedDataSharing else { return }
                let duration = Int(Date().timeIntervalSince(startedAt))
                context.analyticsService.track(
                    "onboarding_completed",
                    properties: ["durationSeconds": String(duration)]
                )
                page = 0
                acceptedDisclaimer = false
                acceptedDataSharing = false
                context.hasCompletedOnboarding = true
            } label: {
                Text(buttonLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mcAccent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(isButtonDisabled)
        }
        .background(Color.mcBackground)
        .onAppear {
            startedAt = Date()
        }
    }

    private var buttonLabel: String {
        switch page {
        case 2:
            return "I consent to data sharing"
        case 3:
            return "I understand and agree"
        default:
            return "Next"
        }
    }

    private var isButtonDisabled: Bool {
        switch page {
        case 2:
            return !acceptedDataSharing
        case 3:
            return !acceptedDisclaimer
        default:
            return false
        }
    }

    private func onboardingCard(illustration: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 200)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.mcTextPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.mcTextSecondary)

            Spacer()
        }
        .padding(24)
    }
}
