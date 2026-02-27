import Foundation

protocol APIServicing {
    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error>
    func fetchHistory(limit: Int, before: String?) async throws -> ConversationListResponse
    func fetchConversation(conversationId: String, limit: Int, before: String?) async throws -> ConversationMessagesResponse
    func fetchV10() async throws -> V10Digest
    func updateV10(digest: String) async throws -> V10Digest
    func revertV10() async throws -> V10Digest
    func fetchSettings() async throws -> UserSettings
    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) async throws -> UserSettings
    func acceptDisclaimer(version: String) async throws -> DisclaimerAcceptResponse
    func deleteAccount() async throws
}

final class APIService: APIServicing {
    private let environment: AppEnvironment
    private let authService: AuthServicing
    private let sseClient: SSEClient
    private let session: URLSession

    init(
        environment: AppEnvironment = .current,
        authService: AuthServicing,
        sseClient: SSEClient = SSEClient(),
        session: URLSession = .shared
    ) {
        self.environment = environment
        self.authService = authService
        self.sseClient = sseClient
        self.session = session
    }

    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        struct AskRequest: Codable {
            let question: String
            let conversationId: String?
        }

        var request = try await authorizedRequest(
            path: "/api/chat/ask",
            method: "POST",
            body: AskRequest(question: question, conversationId: conversationId)
        )
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return try await sseClient.stream(request: request)
    }

    func fetchHistory(limit: Int = 20, before: String? = nil) async throws -> ConversationListResponse {
        var components = URLComponents(url: environment.apiBaseURL.appendingPathComponent("/api/chat/history"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: before))
        }
        components?.queryItems = items

        guard let url = components?.url else { throw APIError.invalidResponse }

        let request = try await authorizedRequest(url: url, method: "GET")
        return try await send(request, decode: ConversationListResponse.self)
    }

    func fetchConversation(conversationId: String, limit: Int = 50, before: String? = nil) async throws -> ConversationMessagesResponse {
        var components = URLComponents(url: environment.apiBaseURL.appendingPathComponent("/api/chat/history/\(conversationId)"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: before))
        }
        components?.queryItems = items

        guard let url = components?.url else { throw APIError.invalidResponse }

        let request = try await authorizedRequest(url: url, method: "GET")
        return try await send(request, decode: ConversationMessagesResponse.self)
    }

    func fetchV10() async throws -> V10Digest {
        let request = try await authorizedRequest(path: "/api/profile/v10", method: "GET")
        return try await send(request, decode: V10Digest.self)
    }

    func updateV10(digest: String) async throws -> V10Digest {
        struct UpdateRequest: Codable { let digest: String }
        let request = try await authorizedRequest(
            path: "/api/profile/v10",
            method: "PUT",
            body: UpdateRequest(digest: digest)
        )
        return try await send(request, decode: V10Digest.self)
    }

    func revertV10() async throws -> V10Digest {
        let request = try await authorizedRequest(path: "/api/profile/v10/revert", method: "POST")
        return try await send(request, decode: V10Digest.self)
    }

    func fetchSettings() async throws -> UserSettings {
        let request = try await authorizedRequest(path: "/api/settings", method: "GET")
        return try await send(request, decode: UserSettings.self)
    }

    func updateSettings(fontSize: UserSettings.FontSize?, highContrast: Bool?) async throws -> UserSettings {
        struct UpdateSettingsRequest: Codable {
            let fontSize: UserSettings.FontSize?
            let highContrast: Bool?
        }

        let request = try await authorizedRequest(
            path: "/api/settings",
            method: "PUT",
            body: UpdateSettingsRequest(fontSize: fontSize, highContrast: highContrast)
        )
        return try await send(request, decode: UserSettings.self)
    }

    func acceptDisclaimer(version: String) async throws -> DisclaimerAcceptResponse {
        struct AcceptRequest: Codable { let disclaimerVersion: String }
        let request = try await authorizedRequest(
            path: "/api/settings/accept-disclaimer",
            method: "POST",
            body: AcceptRequest(disclaimerVersion: version)
        )
        return try await send(request, decode: DisclaimerAcceptResponse.self)
    }

    func deleteAccount() async throws {
        struct DeleteRequest: Codable { let confirmation: String }
        _ = try await send(
            try await authorizedRequest(
                path: "/api/account",
                method: "DELETE",
                body: DeleteRequest(confirmation: "DELETE")
            ),
            decode: EmptyResponse.self
        )
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        let url = environment.apiBaseURL.appendingPathComponent(path)
        return try await authorizedRequest(url: url, method: method)
    }

    private func authorizedRequest<T: Encodable>(path: String, method: String, body: T) async throws -> URLRequest {
        let url = environment.apiBaseURL.appendingPathComponent(path)
        return try await authorizedRequest(url: url, method: method, body: body)
    }

    private func authorizedRequest(url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        let token = try await authService.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func authorizedRequest<T: Encodable>(url: URL, method: String, body: T) async throws -> URLRequest {
        var request = try await authorizedRequest(url: url, method: method)
        request.httpBody = try CodingSupport.encoder.encode(body)
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

            guard (200...299).contains(http.statusCode) else {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                if let errorResponse = try? CodingSupport.decoder.decode(APIErrorResponse.self, from: data) {
                    throw APIError(
                        code: errorResponse.error.code,
                        message: errorResponse.error.message,
                        retryAfter: retryAfter
                    )
                }
                if http.statusCode == 429 {
                    throw APIError.rateLimited(retryAfter: retryAfter)
                }
                throw APIError.serverError
            }

            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            return try CodingSupport.decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch is DecodingError {
            throw APIError.invalidResponse
        } catch is URLError {
            throw APIError.networkError
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }
    }
}

private struct EmptyResponse: Decodable {}
