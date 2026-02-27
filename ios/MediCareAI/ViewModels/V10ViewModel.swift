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

    init(apiService: APIServicing, analytics: AnalyticsServicing) {
        self.apiService = apiService
        self.analytics = analytics
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.fetchV10()
            digest = response
            editableDigest = response.digest ?? ""
            analytics.track(
                "v10_loaded",
                properties: ["hasDigest": response.digest == nil ? "false" : "true"]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }

        isLoading = false
    }

    func save() async {
        let trimmed = editableDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please add at least one detail to your health profile."
            return
        }

        isSaving = true
        errorMessage = nil
        noticeMessage = nil

        do {
            let updated = try await apiService.updateV10(digest: trimmed)
            digest = updated
            editableDigest = updated.digest ?? ""
            noticeMessage = "Health profile saved."
            analytics.track(
                "v10_edited",
                properties: ["source": "manual", "version": String(updated.version)]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }

        isSaving = false
    }

    func revertToPrevious() async {
        guard digest?.canRevert == true else { return }

        isReverting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isReverting = false }

        do {
            let updated = try await apiService.revertV10()
            digest = updated
            editableDigest = updated.digest ?? ""
            noticeMessage = "Previous profile version restored."
            analytics.track(
                "v10_edited",
                properties: ["source": "revert", "version": String(updated.version)]
            )
        } catch {
            errorMessage = ErrorHandling.message(for: error)
        }
    }
}
