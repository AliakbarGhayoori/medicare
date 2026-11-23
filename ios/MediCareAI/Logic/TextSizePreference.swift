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

    @ViewBuilder
    func body(content: Content) -> some View {
        if let minimum {
            content.dynamicTypeSize(minimum...)
        } else {
            content
        }
    }
}
