import SwiftUI
import UIKit

extension Font {
    /// Instrument Serif, the headline face from the MediCare AI website. Only for the
    /// greeting and big screen titles; it scales with the iPhone's text size.
    static func mcDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }
}

/// A big serif screen title, used instead of the navigation bar's large title.
struct ScreenTitle: View {
    let text: String
    var size: CGFloat = 38

    var body: some View {
        Text(text)
            .font(.mcDisplay(size))
            .foregroundStyle(Color.mcInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Large navigation titles in Instrument Serif, scaled for the person's text size at launch.
/// Inline titles keep the system font.
enum NavigationBarStyle {
    static func apply() {
        guard let serif = UIFont(name: "InstrumentSerif-Regular", size: 38) else { return }
        let appearance = UINavigationBar.appearance()
        var attributes = appearance.largeTitleTextAttributes ?? [:]
        attributes[.font] = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: serif)
        attributes[.foregroundColor] = UIColor(named: "MCInk")
        appearance.largeTitleTextAttributes = attributes
    }
}
