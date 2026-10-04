import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primaryContainer)
                    .frame(width: 112, height: 112)
                // The mascot, as on Android's welcome screen.
                Image("LaunchSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }

            Text("Cats & Dogs")
                .font(.brand(.largeTitle, weight: .bold))
                .fontWeight(.semibold)
                .padding(.top, 20)

            Text("Check current conditions and a multi-day forecast for any city.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onGetStarted) {
                Text("Get started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface)
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
