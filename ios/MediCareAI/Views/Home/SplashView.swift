import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 12
    @State private var glowOpacity: Double = 0

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.mcBackground
                .ignoresSafeArea()

            // Soft radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.mcAccent.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                Image("auth-hero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .accessibilityHidden(true)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("MediCare AI")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mcTextPrimary)
                        .opacity(textOpacity)
                        .offset(y: textOffset)

                    Text("Your health, understood.")
                        .font(.callout)
                        .foregroundStyle(Color.mcTextSecondary)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
                glowOpacity = 0.8
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
                textOffset = 0
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.9)) {
                glowOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinished()
            }
        }
    }
}
