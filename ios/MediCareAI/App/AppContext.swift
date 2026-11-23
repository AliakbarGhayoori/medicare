import Foundation
import Combine

@MainActor
final class AppContext: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }

    let authService: AuthService
    let apiService: any APIServicing
    let analyticsService: AnalyticsService

    let authViewModel: AuthViewModel
    let conversationListViewModel: ConversationListViewModel
    let v10ViewModel: V10ViewModel
    let settingsViewModel: SettingsViewModel

    private let onboardingKey = "mc.onboarding.completed"

    init() {
        let processEnv = ProcessInfo.processInfo.environment
        if processEnv["UITEST_ONBOARDING_COMPLETED"] == "true" {
            UserDefaults.standard.set(true, forKey: onboardingKey)
            self.hasCompletedOnboarding = true
        } else if processEnv["UITEST_ONBOARDING_COMPLETED"] == "false" {
            UserDefaults.standard.set(false, forKey: onboardingKey)
            UserDefaults.standard.set(0, forKey: "mc.onboarding.page")
            self.hasCompletedOnboarding = false
        } else {
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        }

        let authService = AuthService(environment: .current)
        if processEnv["UITEST_CLEAR_KEYCHAIN"] == "true" {
            try? authService.signOut()
        }
        let analyticsService = AnalyticsService.shared
        let apiService: any APIServicing
        if AppEnvironment.current.useMockAPI {
            apiService = MockAPIService(seeded: UITestHooks.seedsData)
        } else {
            apiService = APIService(environment: .current, authService: authService)
        }

        self.authService = authService
        self.apiService = apiService
        self.analyticsService = analyticsService

        let authVM = AuthViewModel(authService: authService)
        self.authViewModel = authVM

        self.conversationListViewModel = ConversationListViewModel(
            apiService: apiService,
            analytics: analyticsService
        )
        self.v10ViewModel = V10ViewModel(apiService: apiService, analytics: analyticsService)
        self.settingsViewModel = SettingsViewModel(
            apiService: apiService,
            analytics: analyticsService
        )

        authVM.onSessionEnded = { [weak self] in
            self?.resetSessionState()
        }
    }

    /// Each chat screen gets its own view model, so two chats never mix.
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(apiService: apiService, analytics: analyticsService)
    }

    /// Forgets everything shown for the account that signed out.
    func resetSessionState() {
        conversationListViewModel.reset()
        v10ViewModel.reset()
        settingsViewModel.reset()
    }
}
