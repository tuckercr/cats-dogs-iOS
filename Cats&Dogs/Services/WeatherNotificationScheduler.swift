import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class WeatherNotificationScheduler {
    static let shared = WeatherNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let notificationHours = [9, 13, 19]
    private var requestIdentifiers: [String] { notificationHours.map { "weather_daily_\($0)" } }

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
            removePendingDailyNotifications()
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
            content = ("Sunny & Misty", "Tap to see your weather update.")
        }

        await scheduleDailyNotifications(title: content.title, body: content.body)
    }

    /// Replaces the pending 9 AM / 1 PM / 7 PM notifications with the given text. When Remote Config
    /// switches them off, the pending ones are removed so none fire.
    func scheduleDailyNotifications(title: String, body: String) async {
        removePendingDailyNotifications()
        guard RemoteConfigRepository.shared.dailyWeatherNotificationsEnabled, await isAuthorized() else { return }

        // The brand look: the pets in today's mood, as on the app's top card.
        let picture = petsPicture(preferences: .shared)
        for hour in notificationHours {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let notification = UNMutableNotificationContent()
            notification.title = title
            notification.body = body
            notification.sound = .default
            if let picture, let attachment = Self.attachment(picture, hour: hour) {
                notification.attachments = [attachment]
            }

            let request = UNNotificationRequest(
                identifier: "weather_daily_\(hour)",
                content: notification,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// A PNG of the pets in the mood of the active city's cached weather; nil before there's any.
    private func petsPicture(preferences: PreferencesStore) -> Data? {
        let locations = preferences.savedLocations
        guard !locations.isEmpty else { return nil }
        let location = locations[min(preferences.activeLocationIndex, locations.count - 1)]
        guard let weather = preferences.cachedWeather(for: location.cacheKey) else { return nil }
        let mood = PetMood.forConditions(
            conditionMain: weather.conditionMain,
            iconCode: weather.iconCode,
            temperatureC: weather.units.toCelsius(weather.temperature),
            thresholds: RemoteConfigRepository.shared.petWeatherThresholds
        )
        let renderer = ImageRenderer(
            content: PetSceneIcon(mood: mood, southernHemisphere: (location.latitude ?? 0) < 0)
                .frame(width: 120, height: 120)
        )
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }

    /// Each notification needs its own file: iOS moves an attachment's file into its own store.
    private static func attachment(_ png: Data, hour: Int) -> UNNotificationAttachment? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notification-pets-\(hour)-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return try UNNotificationAttachment(identifier: "pets", url: url)
        } catch {
            return nil
        }
    }

    /// Only this app's daily weather requests, so future notification types are left alone.
    private func removePendingDailyNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
    }
}
