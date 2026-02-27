import Foundation

struct V10Digest: Codable, Equatable {
    let digest: String?
    let previousDigest: String?
    let canRevert: Bool
    let version: Int
    let updatedAt: Date?
    let lastUpdateSource: String?
}
