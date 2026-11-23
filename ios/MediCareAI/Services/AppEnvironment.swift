import Foundation

struct AppEnvironment {
    let apiBaseURL: URL
    let useMockAuth: Bool
    let useMockAPI: Bool

    static let current: AppEnvironment = {
        let processEnv = ProcessInfo.processInfo.environment
        let useMockAuth = processEnv["AUTH_MODE"] == "mock"
        let useMockAPI = processEnv["API_MODE"] == "mock"

        if let raw = processEnv["API_BASE_URL"], let url = URL(string: raw) {
            return AppEnvironment(
                apiBaseURL: url,
                useMockAuth: useMockAuth,
                useMockAPI: useMockAPI
            )
        }

        return AppEnvironment(
            apiBaseURL: URL(string: "https://api.mediguide.co")!,
            useMockAuth: useMockAuth,
            useMockAPI: useMockAPI
        )
    }()
}

/// Switches that only UI tests set. They do nothing unless the app runs with the mock
/// sign-in and the mock API, so the App Store build can never use them.
enum UITestHooks {
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    /// Fills the mock API with sample chats and a health profile, for screenshots.
    static var seedsData: Bool {
        AppEnvironment.current.useMockAPI && environment["UITEST_SEED_DATA"] == "true"
    }

    /// Starts with a signed-in sample account named Inge.
    static var startsSignedIn: Bool {
        AppEnvironment.current.useMockAuth && environment["UITEST_SIGNED_IN"] == "true"
    }

    /// "light" or "dark" to force an appearance.
    static var colorScheme: String? {
        guard AppEnvironment.current.useMockAuth else { return nil }
        return environment["UITEST_COLOR_SCHEME"]
    }
}
