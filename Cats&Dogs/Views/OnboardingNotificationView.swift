import SwiftUI

struct OnboardingNotificationView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 112, height: 112)
                Image(systemName: "bell.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer().frame(height: 32)

            Text("Stay in the loop")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            Text("Get a morning, afternoon, and evening weather update for your active city.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 48)

            Button("Allow notifications") {
                Task {
                    _ = await WeatherNotificationScheduler.shared.requestAuthorization()
                    await WeatherNotificationScheduler.shared.scheduleDailyNotifications()
                    onDone()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 12)

            Button("Not now", action: onDone)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(32)
    }
}

#Preview {
    OnboardingNotificationView(onDone: {})
}
