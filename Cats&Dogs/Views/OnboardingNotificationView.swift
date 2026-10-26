import SwiftUI

struct OnboardingNotificationView: View {
    let onDone: () -> Void

    var body: some View {
        OnboardingLayout {
            ZStack {
                Circle()
                    .fill(Color.primaryContainer)
                    .frame(width: 112, height: 112)
                Image(systemName: "bell.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accent)
            }

            Text("Stay in the loop")
                .font(.brand(.title2))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text("Allow Sunny & Misty to send you daily weather updates for your saved locations.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

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
            .padding(.top, 36)

            Button(action: onDone) {
                Text("Not now").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

#Preview {
    OnboardingNotificationView(onDone: {})
}
