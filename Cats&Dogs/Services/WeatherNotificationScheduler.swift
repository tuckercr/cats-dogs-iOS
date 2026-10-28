import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class WeatherNotificationScheduler {
    static let shared = WeatherNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    nonisolated private static let notificationHours = [9, 13, 19]
    /// How many days of notifications are queued. iOS gives no guaranteed background time, so the
    /// queue has to outlast the gaps between refreshes; each refresh replaces all of it.
    nonisolated private static let daysQueued = 7
    /// The text for queued notifications whose weather isn't known yet.
    nonisolated static let fallbackContent = (title: "Sunny & Misty", body: "Tap to see your weather update.")
    private var requestIdentifiers: [String] {
        Self.plannedNotifications(after: Date()).map(\.identifier)
    }

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
            content = Self.fallbackContent
        }

        await scheduleDailyNotifications(title: content.title, body: content.body)
    }

    /// Replaces the pending 9 AM / 1 PM / 7 PM notifications. The next one at each time gets the given
    /// text; the ones after it get the fallback, since a repeating notification would keep showing
    /// this reading for days if iOS doesn't give the app time to refresh. When Remote Config switches
    /// them off, the pending ones are removed so none fire.
    func scheduleDailyNotifications(title: String, body: String) async {
        removePendingDailyNotifications()
        guard RemoteConfigRepository.shared.dailyWeatherNotificationsEnabled, await isAuthorized() else { return }

        // The brand look: the pets in today's mood, as on the app's top card.
        let picture = petsPicture(preferences: .shared)
        let calendar = Calendar.current
        for planned in Self.plannedNotifications(after: Date(), calendar: calendar) {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: planned.date),
                repeats: false
            )
            let notification = UNMutableNotificationContent()
            notification.title = planned.isNext ? title : Self.fallbackContent.title
            notification.body = planned.isNext ? body : Self.fallbackContent.body
            notification.sound = .default
            if planned.isNext, let picture, let attachment = Self.attachment(picture, identifier: planned.identifier) {
                notification.attachments = [attachment]
            }

            let request = UNNotificationRequest(identifier: planned.identifier, content: notification, trigger: trigger)
            try? await center.add(request)
        }
    }

    struct PlannedNotification: Equatable {
        let identifier: String
        let date: Date
        /// The next notification at its time of day, the only one whose weather is current.
        let isNext: Bool
    }

    /// The queued notifications after `now`: each notification time on each of the next
    /// `daysQueued` days. The next one at each time keeps the original `weather_daily_<hour>`
    /// identifier, which also replaces the repeating requests older versions scheduled.
    nonisolated static func plannedNotifications(after now: Date, calendar: Calendar = .current) -> [PlannedNotification] {
        notificationHours.flatMap { hour -> [PlannedNotification] in
            guard let next = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: hour, minute: 0),
                matchingPolicy: .nextTime
            ) else { return [] }
            return (0..<daysQueued).compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: day, to: next) else { return nil }
                let identifier = day == 0 ? "weather_daily_\(hour)" : "weather_daily_\(hour)_\(day)"
                return PlannedNotification(identifier: identifier, date: date, isNext: day == 0)
            }
        }
        .sorted { $0.date < $1.date }
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
            feelsLikeC: weather.units.toCelsius(weather.feelsLike),
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
    private static func attachment(_ png: Data, identifier: String) -> UNNotificationAttachment? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notification-pets-\(identifier)-\(UUID().uuidString).png")
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
