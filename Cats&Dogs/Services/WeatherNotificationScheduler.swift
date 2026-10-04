import Foundation
import UserNotifications

@MainActor
final class WeatherNotificationScheduler {
    static let shared = WeatherNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let notificationHours = [9, 13, 19]

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func isAuthorized() async -> Bool {
        let status = await authorizationStatus()
        return status == .authorized || status == .provisional
    }

    /// Builds the notification text from the cached weather for the active city. Callers run this
    /// after a refresh has written the cache, so it never needs the network itself.
    func scheduleDailyNotifications(preferences: PreferencesStore? = nil) async {
        let preferences = preferences ?? .shared
        let locations = preferences.savedLocations
        guard !locations.isEmpty, await isAuthorized() else {
            center.removeAllPendingNotificationRequests()
            return
        }

        let activeIndex = min(preferences.activeLocationIndex, locations.count - 1)
        let location = locations[activeIndex]
        let weather = preferences.cachedWeather(for: location.cacheKey)
        let todayForecast = preferences.cachedForecast(for: location.cacheKey).flatMap {
            forecastForToday(in: $0, timeZone: weather?.timeZone ?? .current)
        }

        let content: (title: String, body: String)
        if let weather {
            content = buildNotificationContent(weather: weather, todayForecast: todayForecast)
        } else {
            content = ("Cats & Dogs", "Tap to see your weather update.")
        }

        await scheduleDailyNotifications(title: content.title, body: content.body)
    }

    /// Replaces the pending 9 AM / 1 PM / 7 PM notifications with the given text.
    func scheduleDailyNotifications(title: String, body: String) async {
        center.removeAllPendingNotificationRequests()
        guard await isAuthorized() else { return }

        for hour in notificationHours {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let notification = UNMutableNotificationContent()
            notification.title = title
            notification.body = body
            notification.sound = .default

            let request = UNNotificationRequest(
                identifier: "weather_daily_\(hour)",
                content: notification,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
