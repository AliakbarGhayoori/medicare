import SwiftUI

extension UserSettings.FontSize {
    /// The smallest text size the app allows. `nil` follows the iPhone's own text size.
    /// The old "Regular" and "Large" choices both follow the iPhone now.
    var minimumDynamicType: DynamicTypeSize? {
        self == .extraLarge ? .accessibility1 : nil
    }
}

/// Applies the in-app "Extra large text" choice as a floor, never as a fixed size, so the
/// iPhone's own larger sizes still apply.
struct MinimumTextSize: ViewModifier {
    let minimum: DynamicTypeSize?

    func body(content: Content) -> some View {
        // Always the same modifier, so changing the setting keeps the open tab, screens and
        // typed text; `.xSmall...` allows every size.
        content.dynamicTypeSize((minimum ?? .xSmall)...)
    }
}
