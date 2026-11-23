import SwiftUI

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
