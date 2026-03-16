import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 16
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.mcBackground
                .ignoresSafeArea()

            // Soft radial accent glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.mcAccent.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            VStack(spacing: 18) {
                ZStack {
                    // Pulse ring
                    Circle()
                        .stroke(Color.mcAccent.opacity(0.2), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Logo icon
                    ZStack {
                        Circle()
                            .fill(Color.mcAccent.opacity(0.15))
                            .frame(width: 84, height: 84)

                        Image(systemName: "stethoscope")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.mcAccent)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }

                VStack(spacing: 6) {
                    Text("MediCare AI")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mcTextPrimary)
                        .opacity(textOpacity)
                        .offset(y: textOffset)

                    Text("Your health, understood.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                        .opacity(subtitleOpacity)
                        .offset(y: textOffset)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                ringScale = 1.15
                ringOpacity = 0.6
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
                textOffset = 0
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                subtitleOpacity = 1.0
            }

            // Pulse ring outward then fade
            withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
                ringScale = 1.5
                ringOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onFinished()
            }
        }
    }
}
