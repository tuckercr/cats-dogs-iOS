import SwiftUI

struct OnboardingNotificationView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primaryContainer)
                    .frame(width: 112, height: 112)
                Image(systemName: "bell.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accent)
            }

            Spacer().frame(height: 32)

            Text("Stay in the loop")
                .font(.brand(.title2))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            Text("Allow Sunny & Misty to send you daily weather updates for your saved locations.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 48)

            Button {
                Task {
                    _ = await WeatherNotificationScheduler.shared.requestAuthorization()
                    await WeatherNotificationScheduler.shared.scheduleDailyNotifications()
                    onDone()
                }
            } label: {
                Text("Allow notifications").frame(maxWidth: .infinity)
            }
            .accentButtonStyle()
            .controlSize(.large)

            Spacer().frame(height: 12)

            Button(action: onDone) {
                Text("Not now").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface)
    }
}

#Preview {
    OnboardingNotificationView(onDone: {})
}
