import Foundation
import Combine
import OSLog

@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState {
        case loading
        case authenticated
        case unauthenticated
    }

    @Published var state: AuthState = .loading
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.medicareai.app", category: "AuthViewModel")
    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func checkAuthState() async {
        state = .loading
        do {
            let session = try await authService.refreshSession()
            state = session == nil ? .unauthenticated : .authenticated
        } catch {
            state = .unauthenticated
            errorMessage = APIError.unauthorized.errorDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        logger.info("signIn started")
        do {
            _ = try await authService.signIn(email: email, password: password)
            state = .authenticated
            logger.info("signIn completed and state=authenticated")
        } catch {
            logger.error("signIn failed: \(String(describing: error), privacy: .public)")
            let verboseErrors = ProcessInfo.processInfo.environment["UITEST_VERBOSE_ERRORS"] == "true"
            if verboseErrors {
                let nsError = error as NSError
                errorMessage = "Sign in failed: \(nsError.domain)#\(nsError.code) - \(error.localizedDescription)"
            } else {
                errorMessage = "That email and password do not match our records."
            }
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        logger.info("signUp started")
        do {
            _ = try await authService.signUp(email: email, password: password)
            state = .authenticated
            logger.info("signUp completed and state=authenticated")
        } catch {
            logger.error("signUp failed: \(String(describing: error), privacy: .public)")
            let verboseErrors = ProcessInfo.processInfo.environment["UITEST_VERBOSE_ERRORS"] == "true"
            if verboseErrors {
                let nsError = error as NSError
                errorMessage = "Sign up failed: \(nsError.domain)#\(nsError.code) - \(error.localizedDescription)"
            } else {
                errorMessage = "We could not create your account. Double-check your details and try again."
            }
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            try await authService.sendPasswordReset(email: email)
        } catch {
            errorMessage = "We could not send a password reset email right now."
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            state = .unauthenticated
        } catch {
            errorMessage = "We could not log you out right now."
        }
    }
    
    var currentEmail: String? {
        authService.currentSession?.email
    }
}
