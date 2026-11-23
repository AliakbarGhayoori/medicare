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

    @Published var state: AuthState = .loading {
        didSet {
            if state == .unauthenticated {
                firstName = nil
            }
            if state == .unauthenticated, oldValue != .unauthenticated {
                onSessionEnded?()
            }
            if state == .authenticated {
                refreshFirstName()
            }
        }
    }
    @Published var errorMessage: String?
    /// The name to greet the person with; nil until they tell us.
    @Published private(set) var firstName: String?

    /// Called when the person signs out or the session ends, so every screen forgets the account.
    var onSessionEnded: (@MainActor () -> Void)?

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
            let nsError = error as NSError
            logger.error("signIn failed: \(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
            let verboseErrors = ProcessInfo.processInfo.environment["UITEST_VERBOSE_ERRORS"] == "true"
            if verboseErrors {
                errorMessage = "Sign in failed: \(nsError.domain)#\(nsError.code) - \(error.localizedDescription)"
            } else {
                errorMessage = "That email and password do not match our records."
            }
        }
    }

    func signUp(email: String, password: String, firstName: String? = nil) async {
        errorMessage = nil
        logger.info("signUp started")
        do {
            _ = try await authService.signUp(email: email, password: password)
            if let firstName, Greeting.cleanedFirstName(firstName) != nil {
                await setFirstName(firstName)
            }
            state = .authenticated
            logger.info("signUp completed and state=authenticated")
        } catch {
            let nsError = error as NSError
            logger.error("signUp failed: \(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
            let verboseErrors = ProcessInfo.processInfo.environment["UITEST_VERBOSE_ERRORS"] == "true"
            if verboseErrors {
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

    func refreshFirstName() {
        guard let session = authService.currentSession else {
            firstName = nil
            return
        }
        firstName = NameStore.firstName(for: session.uid) ?? Greeting.cleanedFirstName(session.displayName)
    }

    /// Saves the name to greet the person with. An empty name removes it everywhere, so the
    /// greeting has no name rather than falling back to an older one.
    func setFirstName(_ name: String) async {
        guard let uid = authService.currentSession?.uid else { return }
        let cleaned = Greeting.cleanedFirstName(name)
        NameStore.setFirstName(cleaned, for: uid)
        firstName = cleaned
        await authService.updateDisplayName(cleaned ?? "")
    }

    /// Removes the name kept on this iPhone, before the account is deleted.
    func forgetFirstName() {
        if let uid = authService.currentSession?.uid {
            NameStore.setFirstName(nil, for: uid)
        }
        firstName = nil
    }
}
