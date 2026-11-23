import SwiftUI

/// Brand colours. Each named colour has a light and a dark value in Assets.xcassets;
/// every text pairing meets 4.5:1 in both.
extension Color {
    static let mcInk = Color("MCInk")
    static let mcInk2 = Color("MCInk2")
    static let mcPaper = Color("MCPaper")
    static let mcSurface = Color("MCSurface")
    static let mcLine = Color("MCLine")
    static let mcField = Color("MCField")
    /// Button and bubble fills (white text on top).
    static let mcBlue = Color("MCBlue")
    /// Blue for text and icons on paper or surface.
    static let mcBlueText = Color("MCBlueText")
    static let mcBlueTint = Color("MCBlueTint")
    static let mcCoral = Color("MCCoral")
    static let mcCoralTint = Color("MCCoralTint")
    static let mcCoralInk = Color("MCCoralInk")
    static let mcGreen = Color("MCGreen")
    static let mcGreenTint = Color("MCGreenTint")
    static let mcAmber = Color("MCAmber")
    static let mcAmberTint = Color("MCAmberTint")
    /// Emergency fills (white text on top). Red is only used for emergencies.
    static let mcRed = Color("MCRed")
    static let mcRedText = Color("MCRedText")
    static let mcRedTint = Color("MCRedTint")

    // Settings-style icon tiles; they carry white symbols in both appearances.
    static let tileBlue = Color(hex: 0x2F5BEA)
    static let tileTeal = Color(hex: 0x0F7D86)
    static let tileViolet = Color(hex: 0x6B4BD8)
    static let tileGreen = Color(hex: 0x1E8A4C)
    static let tileRed = Color(hex: 0xD93A49)
    static let tileOrange = Color(hex: 0xC2570C)
    static let tileSlate = Color(hex: 0x5A6578)

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
