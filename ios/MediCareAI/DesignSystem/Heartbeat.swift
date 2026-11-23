import SwiftUI

/// The heartbeat "M" from the app icon.
struct HeartbeatShape: Shape {
    enum Variant {
        /// The icon's mark, in a 100 × 52 box.
        case mark
        /// A longer line with a flat lead-in, drawn after the greeting (200 × 44 box).
        case flourish
    }

    var variant: Variant = .mark

    func path(in rect: CGRect) -> Path {
        let box: CGSize = variant == .mark ? CGSize(width: 100, height: 52) : CGSize(width: 200, height: 44)
        let sx = rect.width / box.width
        let sy = rect.height / box.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        switch variant {
        case .mark:
            path.move(to: p(0, 29.5))
            path.addLine(to: p(7, 29.5))
            path.addCurve(to: p(14, 23.5), control1: p(10, 29.5), control2: p(11.5, 23.5))
            path.addCurve(to: p(19.2, 34.5), control1: p(16.5, 23.5), control2: p(17, 34.5))
            path.addCurve(to: p(25, 13.5), control1: p(21.5, 34.5), control2: p(23, 13.5))
            path.addCurve(to: p(32, 52), control1: p(27.5, 13.5), control2: p(29.5, 52))
            path.addCurve(to: p(44.2, 1.3), control1: p(34.5, 52), control2: p(41.5, 1.3))
            path.addCurve(to: p(50.6, 36.5), control1: p(47, 1.3), control2: p(48, 36.5))
            path.addCurve(to: p(68.5, 0), control1: p(53, 36.5), control2: p(66, 0))
            path.addCurve(to: p(72.5, 40.5), control1: p(71, 0), control2: p(68, 39))
            path.addCurve(to: p(85, 26), control1: p(76, 42), control2: p(80, 27))
            path.addLine(to: p(100, 25.6))
        case .flourish:
            path.move(to: p(2, 30))
            path.addLine(to: p(40, 30))
            path.addCurve(to: p(48, 24), control1: p(44, 30), control2: p(45.5, 24))
            path.addCurve(to: p(54, 36), control1: p(50.5, 24), control2: p(51.5, 36))
            path.addCurve(to: p(62, 12), control1: p(56.5, 36), control2: p(59.5, 12))
            path.addCurve(to: p(72, 43), control1: p(65, 12), control2: p(69, 43))
            path.addCurve(to: p(88, 2), control1: p(75.5, 43), control2: p(84.5, 2))
            path.addCurve(to: p(98, 33), control1: p(91.5, 2), control2: p(94.5, 33))
            path.addCurve(to: p(118, 1), control1: p(101.5, 33), control2: p(114, 1))
            path.addCurve(to: p(122.5, 37.5), control1: p(121.5, 1), control2: p(117.5, 37))
            path.addCurve(to: p(140, 27), control1: p(127, 38), control2: p(132, 27.5))
            path.addLine(to: p(198, 26.5))
        }
        return path
    }
}

/// The heartbeat drawn in the brand gradient: navy (ink in dark mode) into coral and back.
struct HeartbeatLine: View {
    var variant: HeartbeatShape.Variant = .mark
    var lineWidth: CGFloat = 2.5
    /// Draws the line in once when it appears (skipped with Reduce Motion).
    var drawsIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1

    var body: some View {
        HeartbeatShape(variant: variant)
            .trim(from: 0, to: progress)
            .stroke(
                HeartbeatLine.gradient(for: variant),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .accessibilityHidden(true)
            .onAppear {
                guard drawsIn, !reduceMotion else { return }
                progress = 0
                withAnimation(.easeInOut(duration: 1.4).delay(0.25)) {
                    progress = 1
                }
            }
    }

    static func gradient(for variant: HeartbeatShape.Variant) -> LinearGradient {
        let stops: [Gradient.Stop]
        switch variant {
        case .mark:
            stops = [
                .init(color: .mcInk, location: 0), .init(color: .mcInk, location: 0.42),
                .init(color: .mcCoral, location: 0.6), .init(color: .mcCoral, location: 0.7),
                .init(color: .mcInk, location: 0.84), .init(color: .mcInk, location: 1),
            ]
        case .flourish:
            stops = [
                .init(color: .mcInk, location: 0), .init(color: .mcInk, location: 0.4),
                .init(color: .mcCoral, location: 0.54), .init(color: .mcCoral, location: 0.62),
                .init(color: .mcInk, location: 0.74), .init(color: .mcInk, location: 1),
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

/// The small heartbeat mark that stands for the assistant.
struct PulseMark: View {
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 28

    var body: some View {
        HeartbeatLine(variant: .mark, lineWidth: max(1.6, width / 14))
            .frame(width: width, height: width * 0.52)
    }
}

/// A heartbeat with a travelling highlight, shown while the assistant checks sources.
struct HeartbeatActivity: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 34

    var body: some View {
        Group {
            if reduceMotion {
                HeartbeatLine(variant: .mark, lineWidth: 2)
            } else {
                TimelineView(.animation) { context in
                    let period = 1.6
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    ZStack {
                        HeartbeatShape(variant: .mark)
                            .stroke(Color.mcLine, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        HeartbeatShape(variant: .mark)
                            .trim(from: max(0, t - 0.35), to: t)
                            .stroke(
                                HeartbeatLine.gradient(for: .mark),
                                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
        }
        .frame(width: width, height: width * 0.52)
        .accessibilityHidden(true)
    }
}
