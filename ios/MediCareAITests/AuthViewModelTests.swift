import XCTest
@testable import MediCareAI

/// An account service that keeps everything in memory.
private final class FakeAuth: AuthServicing {
    private let uid = "test_\(UUID().uuidString)"
    private var session: AuthSession?

    var currentSession: AuthSession? { session }

    func refreshSession() async throws -> AuthSession? { session }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let new = AuthSession(uid: uid, email: email)
        session = new
        return new
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        try await signIn(email: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {}

    func signOut() throws { session = nil }

    func idToken() async throws -> String { "mock:\(uid)" }

    func updateDisplayName(_ name: String) async {
        if let current = session {
            session = AuthSession(uid: current.uid, email: current.email, displayName: name)
        }
    }
}

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSignUpKeepsTheFirstName() async {
        let viewModel = AuthViewModel(authService: FakeAuth())

        await viewModel.signUp(email: "inge@example.com", password: "longenough", firstName: "inge")

        XCTAssertEqual(viewModel.firstName, "Inge")
    }

    func testClearingTheNameStaysCleared() async {
        let viewModel = AuthViewModel(authService: FakeAuth())
        await viewModel.signUp(email: "inge@example.com", password: "longenough", firstName: "Inge")

        await viewModel.setFirstName("")
        viewModel.refreshFirstName()

        XCTAssertNil(viewModel.firstName)
    }

    func testSigningOutForgetsTheName() async {
        let viewModel = AuthViewModel(authService: FakeAuth())
        await viewModel.signUp(email: "inge@example.com", password: "longenough", firstName: "Inge")

        viewModel.signOut()

        XCTAssertNil(viewModel.firstName)
    }
}
