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
    var displayName: String? = nil
}

protocol AuthServicing {
    var currentSession: AuthSession? { get }
    func refreshSession() async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    func idToken() async throws -> String
    /// Saves the name the person wants to be called with the account (best effort).
    func updateDisplayName(_ name: String) async
}

extension AuthServicing {
    func updateDisplayName(_ name: String) async {}
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
        return AuthSession(uid: user.uid, email: user.email, displayName: user.displayName)
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
        return AuthSession(uid: user.uid, email: user.email, displayName: user.displayName)
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
            return AuthSession(uid: result.user.uid, email: result.user.email, displayName: result.user.displayName)
        } catch {
            let nsError = error as NSError
            logger.error("signIn failed: \(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
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
            let nsError = error as NSError
            logger.error("signUp failed: \(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
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

    func updateDisplayName(_ name: String) async {
        if environment.useMockAuth {
            if let session = mockSession {
                mockSession = AuthSession(uid: session.uid, email: session.email, displayName: name)
            }
            return
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        let change = user.createProfileChangeRequest()
        change.displayName = name
        do {
            try await change.commitChanges()
        } catch {
            logger.error("display name update failed")
        }
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
