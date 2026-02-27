import Foundation
import os.log

private let sseLog = Logger(subsystem: "com.medicareai.app", category: "SSEClient")

final class SSEClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            self.session = URLSession(configuration: config)
        }
    }

    func stream(request: URLRequest) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard http.statusCode == 200 else {
            var payload = Data()
            for try await byte in bytes {
                payload.append(byte)
                if payload.count > 32_768 {
                    break
                }
            }

            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            if let apiError = try? CodingSupport.decoder.decode(APIErrorResponse.self, from: payload) {
                throw APIError(
                    code: apiError.error.code,
                    message: apiError.error.message,
                    retryAfter: retryAfter
                )
            }
            if http.statusCode == 429 {
                throw APIError.rateLimited(retryAfter: retryAfter)
            }
            throw APIError.serverError
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                var currentEvent: String?
                var currentDataLines: [String] = []
                var streamFinished = false

                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        // Empty lines mark the end of an SSE event block.
                        if line.isEmpty {
                            if let event = currentEvent, !currentDataLines.isEmpty {
                                let data = currentDataLines.joined(separator: "\n")
                                streamFinished = process(event: event, data: data, continuation: continuation)
                            }
                            currentEvent = nil
                            currentDataLines.removeAll(keepingCapacity: true)
                            if streamFinished { break }
                            continue
                        }

                        if line.hasPrefix("event: ") {
                            // A new event: line means the previous event is complete.
                            // AsyncLineSequence may skip empty lines from network
                            // streams, so flush the pending event here as well.
                            if let event = currentEvent, !currentDataLines.isEmpty {
                                let data = currentDataLines.joined(separator: "\n")
                                streamFinished = process(event: event, data: data, continuation: continuation)
                                currentDataLines.removeAll(keepingCapacity: true)
                                if streamFinished { break }
                            }
                            currentEvent = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            currentDataLines.append(String(line.dropFirst(6)))
                        }
                    }

                    // Flush any remaining event not terminated by a trailing blank line.
                    if !streamFinished, let event = currentEvent, !currentDataLines.isEmpty {
                        let data = currentDataLines.joined(separator: "\n")
                        streamFinished = process(event: event, data: data, continuation: continuation)
                    }

                    if !streamFinished {
                        continuation.finish()
                    }
                } catch {
                    if !streamFinished {
                        continuation.finish(throwing: APIError.networkError)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Returns `true` if the stream was finished (done or error event).
    @discardableResult
    private func process(
        event: String,
        data: String,
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) -> Bool {
        guard let payloadData = data.data(using: .utf8) else {
            continuation.yield(.error(.invalidResponse))
            return false
        }

        switch event {
        case "token":
            struct TokenPayload: Codable { let text: String }
            if let payload = try? CodingSupport.decoder.decode(TokenPayload.self, from: payloadData) {
                continuation.yield(.token(payload.text))
            }
            return false

        case "tool_use":
            struct ToolPayload: Codable { let tool: String; let status: String }
            if let payload = try? CodingSupport.decoder.decode(ToolPayload.self, from: payloadData) {
                continuation.yield(.searching(tool: payload.tool))
            }
            return false

        case "done":
            do {
                let payload = try CodingSupport.decoder.decode(ChatDonePayload.self, from: payloadData)
                continuation.yield(.done(payload))
                continuation.finish()
            } catch {
                sseLog.error("Failed to decode done payload: \(error, privacy: .public)")
                sseLog.error("Raw data: \(data.prefix(500), privacy: .public)")
                continuation.finish(throwing: APIError.invalidResponse)
            }
            return true

        case "error":
            struct ErrorPayload: Codable { let code: String; let message: String }
            if let payload = try? CodingSupport.decoder.decode(ErrorPayload.self, from: payloadData) {
                continuation.finish(throwing: APIError(code: payload.code, message: payload.message))
            } else {
                continuation.finish(throwing: APIError.serverError)
            }
            return true

        default:
            return false
        }
    }
}
