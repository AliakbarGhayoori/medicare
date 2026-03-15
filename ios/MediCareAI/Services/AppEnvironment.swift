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
            apiBaseURL: URL(string: "http://127.0.0.1:8000")!,
            useMockAuth: useMockAuth,
            useMockAPI: useMockAPI
        )
    }()
}
