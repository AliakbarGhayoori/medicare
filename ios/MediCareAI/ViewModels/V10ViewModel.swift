import Foundation
import Combine

@MainActor
final class V10ViewModel: ObservableObject {
    @Published var digest: V10Digest?
    @Published var editableDigest: String = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isReverting = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private let apiService: APIServicing
    private let analytics: AnalyticsServicing
    /// Goes up on every reset, so a request that was still running for the old account
    /// can't bring its profile back.
    private var generation = 0

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    /// Forgets the signed-out account's health profile.
    func reset() {
        generation += 1
        digest = nil
        editableDigest = ""
        errorMessage = nil
        noticeMessage = nil
        isLoading = false
        isSaving = false
        isReverting = false
    }

    func load() async {
        let started = generation
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchV10()
            guard started == generation else { return }
            digest = response
            editableDigest = response.digest ?? ""
            analytics.track(
                "v10_loaded",
                properties: ["hasDigest": response.digest == nil ? "false" : "true"]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }

        isLoading = false
    }

    func save() async {
        let trimmed = editableDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Write at least one thing about your health before saving."
            return
        }

        let started = generation
        isSaving = true
        errorMessage = nil
        noticeMessage = nil

        do {
            let updated = try await apiService.updateV10(digest: trimmed)
            guard started == generation else { return }
            digest = updated
            editableDigest = updated.digest ?? ""
            noticeMessage = "Your health profile is saved."
            analytics.track(
                "v10_edited",
                properties: ["source": "manual", "version": String(updated.version)]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }

        isSaving = false
    }

    func revertToPrevious() async {
        guard digest?.canRevert == true else { return }

        let started = generation
        isReverting = true
        errorMessage = nil
        noticeMessage = nil

        do {
            let updated = try await apiService.revertV10()
            guard started == generation else { return }
            digest = updated
            editableDigest = updated.digest ?? ""
            noticeMessage = "Your profile is back to how it was."
            analytics.track(
                "v10_edited",
                properties: ["source": "revert", "version": String(updated.version)]
            )
        } catch {
            guard started == generation else { return }
            errorMessage = ErrorHandling.message(for: error)
        }
        isReverting = false
    }
}
