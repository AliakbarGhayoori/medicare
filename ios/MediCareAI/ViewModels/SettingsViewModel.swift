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

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            settings = try await apiService.fetchSettings()
            analytics.track(
                "settings_loaded",
                properties: [
                    "fontSize": settings.fontSize.rawValue,
                    "highContrast": settings.highContrast ? "true" : "false"
                ]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }

    func update(fontSize: UserSettings.FontSize? = nil, highContrast: Bool? = nil) async {
        isSaving = true
        defer { isSaving = false }

        do {
            settings = try await apiService.updateSettings(fontSize: fontSize, highContrast: highContrast)
            var changed: [String] = []
            if fontSize != nil { changed.append("fontSize") }
            if highContrast != nil { changed.append("highContrast") }
            analytics.track(
                "settings_changed",
                properties: ["fields": changed.joined(separator: ",")]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }

    func acceptDisclaimerIfNeeded() async {
        guard settings.disclaimerAcceptedAt == nil else { return }

        do {
            _ = try await apiService.acceptDisclaimer(version: "1.0")
            settings = try await apiService.fetchSettings()
            analytics.track("onboarding_completed", properties: ["disclaimerVersion": "1.0"])
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }

    func logout() {
        analytics.track("logout", properties: [:])
    }

    func deleteAccount() async {
        do {
            try await apiService.deleteAccount()
            analytics.track("account_deleted", properties: [:])
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }
}
