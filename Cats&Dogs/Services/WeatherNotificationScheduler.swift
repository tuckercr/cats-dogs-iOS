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

    /// Builds the notification text from the cached weather for the active city.
    func scheduleDailyNotifications(
        preferences: PreferencesStore? = nil,
        weatherRepository: WeatherRepository? = nil
    ) async {
        let preferences = preferences ?? .shared
        let weatherRepository = weatherRepository ?? WeatherRepository()
        let locations = preferences.savedLocations
        guard !locations.isEmpty, await isAuthorized() else {
            center.removeAllPendingNotificationRequests()
            return
        }

        let activeIndex = min(preferences.activeLocationIndex, locations.count - 1)
        let location = locations[activeIndex]
        let units = WeatherUnitsResolver.resolve(override: preferences.unitOverride)

        var weather = preferences.cachedWeather(for: location.cacheKey)
        if weather == nil {
            weather = try? await weatherRepository.fetchCurrentWeather(
                units: units,
                locationLabel: location.label,
                cityQuery: location.latitude == nil ? location.label : nil,
                latitude: location.latitude,
                longitude: location.longitude
            ).get()
        }

        let forecast = preferences.cachedForecast(for: location.cacheKey)
        let todayForecast = forecast?.first

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
