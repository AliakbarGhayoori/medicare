import Foundation
import OSLog

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct AuthSession: Equatable {
    let uid: String
    let email: String?
}

protocol AuthServicing {
    var currentSession: AuthSession? { get }
    func refreshSession() async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    func idToken() async throws -> String
}

final class AuthService: AuthServicing {
    private let logger = Logger(subsystem: "com.medicareai.app", category: "AuthService")
    private let environment: AppEnvironment

    private var mockSession: AuthSession?

    init(environment: AppEnvironment = .current) {
        self.environment = environment
        configureFirebaseIfAvailable()
    }

    var currentSession: AuthSession? {
        if environment.useMockAuth {
            return mockSession
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthSession(uid: user.uid, email: user.email)
        #else
        return mockSession
        #endif
    }

    func refreshSession() async throws -> AuthSession? {
        if environment.useMockAuth {
            return mockSession
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return nil }
        _ = try await user.getIDTokenResult()
        return AuthSession(uid: user.uid, email: user.email)
        #else
        return mockSession
        #endif
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        logger.info("signIn requested (mockAuth=\(self.environment.useMockAuth, privacy: .public))")
        if environment.useMockAuth {
            let uid = "uid_\(abs(email.hashValue))"
            let session = AuthSession(uid: uid, email: email)
            mockSession = session
            return session
        }

        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            logger.info("signIn succeeded")
            return AuthSession(uid: result.user.uid, email: result.user.email)
        } catch {
            logger.error("signIn failed: \(String(describing: error), privacy: .public)")
            throw error
        }
        #else
        throw APIError.unknown("FirebaseAuth SDK is not available in this build.")
        #endif
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        logger.info("signUp requested (mockAuth=\(self.environment.useMockAuth, privacy: .public))")
        if environment.useMockAuth {
            let uid = "uid_\(abs(email.hashValue))"
            let session = AuthSession(uid: uid, email: email)
            mockSession = session
            return session
        }

        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            logger.info("signUp succeeded")
            return AuthSession(uid: result.user.uid, email: result.user.email)
        } catch {
            logger.error("signUp failed: \(String(describing: error), privacy: .public)")
            throw error
        }
        #else
        throw APIError.unknown("FirebaseAuth SDK is not available in this build.")
        #endif
    }

    func sendPasswordReset(email: String) async throws {
        if environment.useMockAuth {
            return
        }

        #if canImport(FirebaseAuth)
        try await Auth.auth().sendPasswordReset(withEmail: email)
        #else
        throw APIError.unknown("FirebaseAuth SDK is not available in this build.")
        #endif
    }

    func signOut() throws {
        if environment.useMockAuth {
            mockSession = nil
            return
        }

        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #else
        mockSession = nil
        #endif
    }

    func idToken() async throws -> String {
        if environment.useMockAuth {
            guard let session = mockSession else {
                throw APIError.unauthorized
            }
            return "mock:\(session.uid)"
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw APIError.unauthorized
        }
        return try await user.getIDToken()
        #else
        throw APIError.unauthorized
        #endif
    }

    private func configureFirebaseIfAvailable() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            logger.info("Firebase configured from bundled plist")
        }
        #endif
    }
}
