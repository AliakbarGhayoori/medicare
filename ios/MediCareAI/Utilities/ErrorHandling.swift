import Foundation

enum ErrorHandling {
    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Something went wrong on our side. Please try again."
        }

        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }

        return APIError.networkError.errorDescription ?? "Something went wrong on our side. Please try again."
    }
}
