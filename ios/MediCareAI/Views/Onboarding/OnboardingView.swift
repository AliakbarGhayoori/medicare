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

    // MARK: - Page 1: Welcome (heroFullBleed)

    private var welcomePage: some View {
        VStack(spacing: 0) {
            // Full-bleed hero — image fills the zone edge to edge
            Image("onboarding-welcome")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .clipShape(UnevenRoundedRectangle(
                    bottomLeadingRadius: 24, bottomTrailingRadius: 24
                ))
                .accessibilityHidden(true)

            Spacer(minLength: 12)

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

            Spacer(minLength: 12)
        }
    }

    // MARK: - Page 2: Personalization (heroFullBleed)

    private var personalizedPage: some View {
        VStack(spacing: 0) {
            Image("onboarding-personalized")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .clipShape(UnevenRoundedRectangle(
                    bottomLeadingRadius: 24, bottomTrailingRadius: 24
                ))
                .accessibilityHidden(true)

            Spacer(minLength: 12)

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

            Spacer(minLength: 12)
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

struct EyebrowChip: View {
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

struct ProofChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.mcTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.mcBackgroundSecondary)
            .clipShape(Capsule())
    }
}

/// Tinted plate container for supportPlate images (3, 4, 5, 8)
struct ImagePlate: View {
    let name: String
    var maxSize: CGFloat = 160

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxSize, maxHeight: maxSize)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.mcBackgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.mcDivider, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            )
            .accessibilityHidden(true)
    }
}
