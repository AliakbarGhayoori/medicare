import SwiftUI

struct RootView: View {
    @EnvironmentObject private var context: AppContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                switch authViewModel.state {
                case .loading:
                    LoadingView()

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
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .modifier(MinimumTextSize(minimum: settingsViewModel.settings.fontSize.minimumDynamicType))
        .contrast(settingsViewModel.settings.highContrast ? 1.2 : 1.0)
        .tint(Color.mcBlueText)
        .task {
            context.analyticsService.track("app_launched", properties: [:])
            await authViewModel.checkAuthState()
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            HeartbeatActivity()
            Text("Getting things ready…")
                .font(.body)
                .foregroundStyle(Color.mcInk2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mcScreenBackground()
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .accessibilityIdentifier("tab.home")

            NavigationStack {
                V10MemoryView()
            }
            .tabItem {
                Label("My health", systemImage: "heart.fill")
            }
            .accessibilityIdentifier("tab.health")

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
