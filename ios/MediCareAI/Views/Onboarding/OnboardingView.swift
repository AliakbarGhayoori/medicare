import SwiftUI

/// Four short pages before the first sign-in: what the app does, how it fits the person,
/// what gets shared (consent) and what it is not (agreement).
struct OnboardingView: View {
    @EnvironmentObject private var context: AppContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("mc.onboarding.page") private var page = 0
    @AppStorage("mc.onboarding.acceptedDisclaimer") private var acceptedDisclaimer = false
    @AppStorage("mc.onboarding.acceptedDataSharing") private var acceptedDataSharing = false
    @State private var startedAt = Date()

    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                WelcomePage().tag(0)
                PersonalPage().tag(1)
                DataPrivacyView(acceptedDataSharing: $acceptedDataSharing).tag(2)
                DisclaimerView(acceptedDisclaimer: $acceptedDisclaimer).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 16) {
                PageDots(count: totalPages, current: page)
                Button(action: next) {
                    Text(buttonLabel)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isButtonDisabled)
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .mcScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding")
        .onAppear { startedAt = Date() }
    }

    private var buttonLabel: String {
        page == totalPages - 1 ? "Get started" : "Continue"
    }

    private var isButtonDisabled: Bool {
        switch page {
        case 2: return !acceptedDataSharing
        case 3: return !acceptedDisclaimer
        default: return false
        }
    }

    private func next() {
        if page < totalPages - 1 {
            if reduceMotion {
                page += 1
            } else {
                withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
            }
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
    }
}

/// Small capsules that show which page is on screen.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.mcBlue : Color.mcLine)
                    .frame(width: index == current ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// A scrolling page with a serif title and body text.
struct OnboardingPage<Content: View>: View {
    let title: String
    let text: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.mcDisplay(38, relativeTo: .largeTitle))
                    .foregroundStyle(Color.mcInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.mcInk2)
                    .fixedSize(horizontal: false, vertical: true)
                content
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage(
            title: "Health answers you can trust",
            text: "Ask in your own words, by typing or talking. Every answer names the trusted sources it comes from."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HeartbeatLine(variant: .flourish, lineWidth: 3, drawsIn: true)
                    .frame(width: 220, height: 48)
                FeatureRow(
                    symbol: "checkmark.seal.fill",
                    tint: .tileBlue,
                    title: "Sources named",
                    detail: "Each answer shows where its facts come from."
                )
                FeatureRow(
                    symbol: "text.bubble.fill",
                    tint: .tileTeal,
                    title: "Plain language",
                    detail: "A short answer first, then what to do and what to watch for."
                )
                FeatureRow(
                    symbol: "lock.fill",
                    tint: .tileSlate,
                    title: "Private to you",
                    detail: "Never sold and never used for ads."
                )
            }
        }
    }
}

private struct PersonalPage: View {
    var body: some View {
        OnboardingPage(
            title: "Answers that fit you",
            text: "Tell MediCare AI about your conditions and medicines. It remembers them and takes them into account in every answer."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    sampleRow(symbol: "stethoscope", tint: .tileRed, title: "Conditions", item: "Type 2 diabetes")
                    Divider()
                        .overlay(Color.mcLine)
                        .padding(.leading, 56)
                    sampleRow(symbol: "pills.fill", tint: .tileTeal, title: "Medicines", item: "Metformin 500 mg with breakfast")
                }
                .background(Color.mcSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.mcLine.opacity(0.7), lineWidth: 0.5)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Example: conditions, type 2 diabetes. Medicines, metformin 500 milligrams with breakfast.")

                Label("You can change or delete it any time in My health.", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcInk2)
            }
        }
    }

    private func sampleRow(symbol: String, tint: Color, title: String, item: String) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: symbol, color: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcInk2)
                Text(item)
                    .font(.body)
                    .foregroundStyle(Color.mcInk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
