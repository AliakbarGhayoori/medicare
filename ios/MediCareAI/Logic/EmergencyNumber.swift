import Foundation

/// The phone number for an ambulance where the iPhone is set up.
enum EmergencyNumber {
    /// Works on mobile phones in the EU and most other countries.
    static let fallback = "112"

    private static let byRegion: [String: String] = [
        "US": "911", "CA": "911", "MX": "911", "PR": "911", "VI": "911", "GU": "911",
        "PA": "911", "CR": "911", "PH": "911",
        "GB": "999", "HK": "999",
        "AU": "000",
        "NZ": "111",
        "JP": "119", "KR": "119", "TW": "119",
        "CN": "120",
        "SG": "995",
        "NO": "113",
        "BR": "192",
        "IL": "101",
        "SA": "997",
        "AE": "998",
    ]

    static func number(forRegion region: String?) -> String {
        guard let region else { return fallback }
        return byRegion[region.uppercased()] ?? fallback
    }

    static func countryName(forRegion region: String?) -> String? {
        guard let region, !region.isEmpty else { return nil }
        return Locale(identifier: "en_US").localizedString(forRegionCode: region.uppercased())
    }

    /// Countries whose English name takes "the".
    private static let namedWithThe: Set<String> = [
        "US", "GB", "AE", "NL", "PH", "DO", "BS", "GM", "CF", "KM", "MV", "MH", "SB", "SC", "VA",
        "VI", "VG", "KY", "FO", "FK", "MP", "TC", "CK", "AX", "CC", "UM", "IO", "PS", "TF",
    ]

    /// The country as it reads after "in": "the United States", "Denmark".
    static func countryPhrase(forRegion region: String?) -> String? {
        guard let region, let name = countryName(forRegion: region) else { return nil }
        return namedWithThe.contains(region.uppercased()) ? "the \(name)" : name
    }

    static var currentRegion: String? {
        Locale.current.region?.identifier
    }

    static var current: String {
        number(forRegion: currentRegion)
    }
}
