import Foundation

struct UserSettings: Codable, Equatable {
    var fontSize: FontSize
    var highContrast: Bool
    let disclaimerAcceptedAt: Date?
    let disclaimerVersion: String?

    enum FontSize: String, Codable, CaseIterable {
        case regular
        case large
        case extraLarge

        var label: String {
            switch self {
            case .regular: return "Regular"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
    }

    static let `default` = UserSettings(
        fontSize: .large,
        highContrast: false,
        disclaimerAcceptedAt: nil,
        disclaimerVersion: nil
    )
}

struct DisclaimerAcceptResponse: Codable {
    let accepted: Bool
    let disclaimerVersion: String
    let acceptedAt: Date
}
