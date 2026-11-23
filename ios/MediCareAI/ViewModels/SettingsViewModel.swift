import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: UserSettings = .default
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let apiService: APIServicing
    private let analytics: AnalyticsServicing
    /// Goes up on every reset, so a request that was still running for the old account
    /// can't bring its settings back.
    private var generation = 0

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    /// Back to defaults after the account signs out.
    func reset() {
        generation += 1
        settings = .default
        errorMessage = nil
        isLoading = false
        isSaving = false
    }

    func load() async {
        let started = generation
        isLoading = true

        do {
            let loaded = try await apiService.fetchSettings()
            guard started == generation else { return }
            settings = loaded
            analytics.track(
                "settings_loaded",
                properties: [
                    "fontSize": settings.fontSize.rawValue,
                    "highContrast": settings.highContrast ? "true" : "false"
                ]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }
        isLoading = false
    }

    func update(fontSize: UserSettings.FontSize? = nil, highContrast: Bool? = nil) async {
        let started = generation
        isSaving = true

        do {
            let updated = try await apiService.updateSettings(fontSize: fontSize, highContrast: highContrast)
            guard started == generation else { return }
            settings = updated
            var changed: [String] = []
            if fontSize != nil { changed.append("fontSize") }
            if highContrast != nil { changed.append("highContrast") }
            analytics.track(
                "settings_changed",
                properties: ["fields": changed.joined(separator: ",")]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }
        isSaving = false
    }

    func acceptDisclaimerIfNeeded() async {
        guard settings.disclaimerAcceptedAt == nil else { return }
        let started = generation

        do {
            _ = try await apiService.acceptDisclaimer(version: "1.0")
            let loaded = try await apiService.fetchSettings()
            guard started == generation else { return }
            settings = loaded
            analytics.track("onboarding_completed", properties: ["disclaimerVersion": "1.0"])
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }
    }

    func logout() {
        analytics.track("logout", properties: [:])
    }

    /// - Returns: true when the account is gone.
    @discardableResult
    func deleteAccount() async -> Bool {
        errorMessage = nil
        do {
            try await apiService.deleteAccount()
            analytics.track("account_deleted", properties: [:])
            return true
        } catch {
            errorMessage = ErrorHandling.message(for: error)
            return false
        }
    }
}
