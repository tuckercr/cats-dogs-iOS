import SwiftUI

/// The first onboarding screen: introduces Sunny and Misty, who tell you the weather.
struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        OnboardingLayout {
            PetScene(mood: .sunny)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                .background(PetMood.sunny.skyColor, in: RoundedRectangle(cornerRadius: 24))

            Text("Meet Sunny & Misty")
                .font(.brand(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)

            character(
                name: "Sunny",
                body: "Loves a walk in almost any weather, and always knows the best time to head out."
            )
            .padding(.top, 8)
            character(
                name: "Misty",
                body: "Prefers the window seat, and will tell you when it's a day for staying in."
            )

            Text("Together they check the sky so you know what to expect, for you and your pets.")
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button(action: onGetStarted) {
                Text("Get started").frame(maxWidth: .infinity)
            }
            .accentButtonStyle()
            .controlSize(.large)
            .padding(.top, 20)
        }
    }

    private func character(name: String, body: String) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.brand(.title2))
                .foregroundStyle(Color.accent)
            Text(body)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
