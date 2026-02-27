import Foundation

enum CodingSupport {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                throw DecodingError.valueNotFound(
                    Date.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "null date")
                )
            }

            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractional.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.default.date(from: value) {
                return date
            }

            // Backend may omit timezone designator — try appending "Z" (UTC).
            if let date = ISO8601DateFormatter.withFractional.date(from: value + "Z") {
                return date
            }

            if let date = ISO8601DateFormatter.default.date(from: value + "Z") {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension ISO8601DateFormatter {
    static let `default`: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
