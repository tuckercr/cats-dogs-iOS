import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 112, height: 112)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }

            Text("Cats & Dogs")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.top, 20)

            Text("Check current conditions and a multi-day forecast for any city.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Get started", action: onGetStarted)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(32)
        .background(Color.accentColor.opacity(0.12))
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
