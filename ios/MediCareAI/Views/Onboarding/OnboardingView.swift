import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var context: AppContext

    @AppStorage("mc.onboarding.page") private var page = 0
    @AppStorage("mc.onboarding.acceptedDisclaimer") private var acceptedDisclaimer = false
    @AppStorage("mc.onboarding.acceptedDataSharing") private var acceptedDataSharing = false
    @State private var startedAt = Date()

    private let totalPages = 4

    var body: some View {
        ZStack {
            Color.mcBackground.ignoresSafeArea()

            // Soft ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.mcAccent.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .offset(y: -120)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    personalizedPage.tag(1)
                    DataPrivacyView(acceptedDataSharing: $acceptedDataSharing).tag(2)
                    DisclaimerView(acceptedDisclaimer: $acceptedDisclaimer).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom dock: progress + CTA
                VStack(spacing: 16) {
                    // Progress capsules
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(index == page ? Color.mcAccent : Color.mcDivider)
                                .frame(width: index == page ? 24 : 8, height: 6)
                                .animation(.easeInOut(duration: 0.25), value: page)
                        }
                    }

                    Button {
                        if page < totalPages - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
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
                    .disabled(isButtonDisabled)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .padding(.top, 12)
            }
        }
        .onAppear { startedAt = Date() }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            // Hero zone
            Image("onboarding-welcome")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 220)
                .accessibilityHidden(true)
                .padding(.top, 60)

            Spacer(minLength: 16)

            // Content dock
            VStack(spacing: 14) {
                EyebrowChip(text: "Evidence-backed")

                Text("Health Answers You Can Trust")
                    .font(.title2.bold())
                    .foregroundStyle(Color.mcTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Clear, evidence-backed guidance with sources you can verify.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    ProofChip(text: "Trusted sources")
                    ProofChip(text: "Plain language")
                    ProofChip(text: "Private")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .fill(Color.mcBackgroundSecondary.opacity(0.5))
            )
        }
    }

    // MARK: - Page 2: Personalization

    private var personalizedPage: some View {
        VStack(spacing: 0) {
            Image("onboarding-personalized")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 200)
                .accessibilityHidden(true)
                .padding(.top, 60)

            Spacer(minLength: 16)

            VStack(spacing: 14) {
                EyebrowChip(text: "More helpful over time")

                Text("Personalized for You")
                    .font(.title2.bold())
                    .foregroundStyle(Color.mcTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Share medications, conditions, and health goals so answers fit your situation.")
                    .font(.callout)
                    .foregroundStyle(Color.mcTextSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    ProofChip(text: "Medications")
                    ProofChip(text: "Conditions")
                    ProofChip(text: "Care goals")
                }
                .padding(.top, 4)

                Text("You can edit this anytime.")
                    .font(.caption)
                    .foregroundStyle(Color.mcTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .fill(Color.mcBackgroundSecondary.opacity(0.5))
            )
        }
    }

    // MARK: - Helpers

    private var buttonLabel: String {
        switch page {
        case 2: return "I consent to data sharing"
        case 3: return "Get Started"
        default: return "Continue"
        }
    }

    private var isButtonDisabled: Bool {
        switch page {
        case 2: return !acceptedDataSharing
        case 3: return !acceptedDisclaimer
        default: return false
        }
    }
}

// MARK: - Small Components

private struct EyebrowChip: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(Color.mcAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.mcAccent.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct ProofChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.mcTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.mcBackgroundSecondary.opacity(0.6))
            .clipShape(Capsule())
    }
}
