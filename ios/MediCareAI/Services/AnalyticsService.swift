import Foundation
import OSLog

protocol AnalyticsServicing {
    func track(_ event: String, properties: [String: String])
}

final class AnalyticsService: AnalyticsServicing {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: "com.medicareai.app", category: "analytics")

    func track(_ event: String, properties: [String: String] = [:]) {
        let payload = properties
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")

        if payload.isEmpty {
            logger.info("event=\(event, privacy: .public)")
        } else {
            logger.info("event=\(event, privacy: .public) properties=\(payload, privacy: .public)")
        }
    }
}
