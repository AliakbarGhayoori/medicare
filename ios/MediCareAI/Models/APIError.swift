import Foundation

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

enum APIError: LocalizedError {
    case unauthorized
    case tokenExpired
    case validationError(String)
    case notFound
    case rateLimited(retryAfter: Int?)
    case aiError
    case aiTimeout
    case serverError
    case networkError
    case invalidResponse
    case unknown(String)

    init(code: String, message: String, retryAfter: Int? = nil) {
        switch code {
        case "UNAUTHORIZED":
            self = .unauthorized
        case "TOKEN_EXPIRED":
            self = .tokenExpired
        case "VALIDATION_ERROR":
            self = .validationError(message)
        case "NOT_FOUND":
            self = .notFound
        case "RATE_LIMITED":
            self = .rateLimited(retryAfter: retryAfter)
        case "AI_ERROR":
            self = .aiError
        case "AI_TIMEOUT":
            self = .aiTimeout
        case "INTERNAL_ERROR":
            self = .serverError
        default:
            self = .unknown(message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized, .tokenExpired:
            return "Your session ended. Please sign in again."
        case .validationError(let message):
            return message
        case .notFound:
            return "We could not find what you were looking for."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "You are sending requests too quickly. Please wait \(retryAfter) seconds."
            }
            return "You are sending requests too quickly. Please wait a moment."
        case .aiError, .aiTimeout:
            return "I could not generate a response right now. Please try again."
        case .serverError:
            return "Something went wrong on our end. Please try again shortly."
        case .networkError:
            return "You are offline. Check your connection and try again."
        case .invalidResponse:
            return "We received an unexpected response from the server."
        case .unknown(let message):
            return message
        }
    }

    var analyticsCode: String {
        switch self {
        case .unauthorized:
            return "UNAUTHORIZED"
        case .tokenExpired:
            return "TOKEN_EXPIRED"
        case .validationError:
            return "VALIDATION_ERROR"
        case .notFound:
            return "NOT_FOUND"
        case .rateLimited:
            return "RATE_LIMITED"
        case .aiError:
            return "AI_ERROR"
        case .aiTimeout:
            return "AI_TIMEOUT"
        case .serverError:
            return "INTERNAL_ERROR"
        case .networkError:
            return "NETWORK_ERROR"
        case .invalidResponse:
            return "INVALID_RESPONSE"
        case .unknown:
            return "UNKNOWN"
        }
    }
}
