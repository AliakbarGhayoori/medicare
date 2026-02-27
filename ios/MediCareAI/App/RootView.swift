import SwiftUI

struct RootView: View {
    @EnvironmentObject private var context: AppContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView("Getting things ready...")
                    .font(.body)

            case .unauthenticated:
                if context.hasCompletedOnboarding {
                    LoginView()
                } else {
                    OnboardingView()
                }

            case .authenticated:
                MainTabView()
                    .task {
                        await settingsViewModel.load()
                        await settingsViewModel.acceptDisclaimerIfNeeded()
                    }
            }
        }
        .dynamicTypeSize(dynamicTypeSize)
        .contrast(settingsViewModel.settings.highContrast ? 1.2 : 1.0)
        .task {
            context.analyticsService.track("app_launched", properties: [:])
            await authViewModel.checkAuthState()
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch settingsViewModel.settings.fontSize {
        case .regular:
            return .large
        case .large:
            return .xLarge
        case .extraLarge:
            return .accessibility1
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ConversationListView()
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            .accessibilityIdentifier("tab.chat")

            NavigationStack {
                V10MemoryView()
            }
            .tabItem {
                Label("Health Profile", systemImage: "heart.text.square.fill")
            }
            .accessibilityIdentifier("tab.healthProfile")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .accessibilityIdentifier("tab.settings")
        }
        .accessibilityIdentifier("tab.main")
    }
}
