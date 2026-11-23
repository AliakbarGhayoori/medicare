import SwiftUI

/// The heartbeat draws in, the name fades up, then the app opens.
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsName = false

    var body: some View {
        VStack(spacing: 18) {
            HeartbeatLine(variant: .mark, lineWidth: 5, drawsIn: true)
                .frame(width: 120, height: 62)
            VStack(spacing: 6) {
                Text("MediCare AI")
                    .font(.mcDisplay(44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.mcInk)
                Text("Your health, understood.")
                    .font(.body)
                    .foregroundStyle(Color.mcInk2)
            }
            .opacity(showsName ? 1 : 0)
            .offset(y: showsName || reduceMotion ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mcScreenBackground()
        .accessibilityElement(children: .combine)
        .task {
            if reduceMotion {
                showsName = true
            } else {
                withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                    showsName = true
                }
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.7))
            onFinished()
        }
    }
}
