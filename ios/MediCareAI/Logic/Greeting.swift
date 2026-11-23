import Foundation

enum Greeting {
    static func text(hour: Int, firstName: String?) -> String {
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        guard let name = cleanedFirstName(firstName) else { return base }
        return "\(base), \(name)"
    }

    /// First word of what the person typed, capitalised, at most 24 characters.
    static func cleanedFirstName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let first = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? trimmed
        let short = String(first.prefix(24))
        return short.prefix(1).uppercased() + short.dropFirst()
    }
}

/// The name the person asked to be called, kept on this iPhone per account.
enum NameStore {
    private static func key(for uid: String) -> String { "mc.firstName.\(uid)" }

    static func firstName(for uid: String, defaults: UserDefaults = .standard) -> String? {
        Greeting.cleanedFirstName(defaults.string(forKey: key(for: uid)))
    }

    static func setFirstName(_ name: String?, for uid: String, defaults: UserDefaults = .standard) {
        if let cleaned = Greeting.cleanedFirstName(name) {
            defaults.set(cleaned, forKey: key(for: uid))
        } else {
            defaults.removeObject(forKey: key(for: uid))
        }
    }
}
