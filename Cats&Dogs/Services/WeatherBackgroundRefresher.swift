import BackgroundTasks
import Foundation

/// iOS counterpart of Android's `WeatherUpdateWorker` and `WeatherNotificationWorker`.
///
/// iOS cannot run code at a fixed time of day, so one `BGAppRefreshTask` does both jobs whenever
/// the system grants background time: it refreshes the active city's cache, then rewrites the
/// pending 9 AM / 1 PM / 7 PM local notifications with the fresh text.
@MainActor
final class WeatherBackgroundRefresher {
    static let shared = WeatherBackgroundRefresher()

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    nonisolated static let taskIdentifier = "com.tuckercr.Cats-Dogs.refresh"
    /// Matches Android's default `weather_refresh_interval_minutes`. iOS treats it as a minimum.
    nonisolated static let refreshInterval: TimeInterval = 30 * 60
    nonisolated static let retryInterval: TimeInterval = 15 * 60

    private let preferences: PreferencesStore
    private let weatherRepository: WeatherRepository
    private let notificationsAuthorized: () async -> Bool
    private let scheduleNotifications: (_ title: String, _ body: String) async -> Void
    private let submitRefreshRequest: (_ earliestBegin: Date) -> Void

    init(
        preferences: PreferencesStore? = nil,
        weatherRepository: WeatherRepository? = nil,
        notificationsAuthorized: @escaping () async -> Bool = {
            await WeatherNotificationScheduler.shared.isAuthorized()
        },
        scheduleNotifications: @escaping (_ title: String, _ body: String) async -> Void = { title, body in
            await WeatherNotificationScheduler.shared.scheduleDailyNotifications(title: title, body: body)
        },
        submitRefreshRequest: @escaping (_ earliestBegin: Date) -> Void = { earliestBegin in
            let request = BGAppRefreshTaskRequest(identifier: WeatherBackgroundRefresher.taskIdentifier)
            request.earliestBeginDate = earliestBegin
            // Fails on the simulator and when Background App Refresh is off; nothing to recover.
            try? BGTaskScheduler.shared.submit(request)
        }
    ) {
        self.preferences = preferences ?? .shared
        self.weatherRepository = weatherRepository ?? WeatherRepository()
        self.notificationsAuthorized = notificationsAuthorized
        self.scheduleNotifications = scheduleNotifications
        self.submitRefreshRequest = submitRefreshRequest
    }

    /// Asks iOS for the next refresh. A new request replaces any pending one.
    func scheduleNextRefresh(after interval: TimeInterval = WeatherBackgroundRefresher.refreshInterval) {
        submitRefreshRequest(Date(timeIntervalSinceNow: interval))
    }

    /// Entry point for the `BGAppRefreshTask`.
    func handleAppRefresh() async {
        // Queue the next run first so the chain survives this one being cut short.
        scheduleNextRefresh()
        if await performRefresh() == .retry {
            scheduleNextRefresh(after: Self.retryInterval)
        }
    }

    @discardableResult
    func performRefresh() async -> NotificationWorkerResult {
        let locations = preferences.savedLocations
        let activeIndex = preferences.activeLocationIndex
        let activeLocation = locations.indices.contains(activeIndex) ? locations[activeIndex] : nil
        let cacheKey = activeLocation?.cacheKey
        // Same display-name rule as the foreground refresh in WeatherForecastViewModel.
        let usesApiCityName = activeLocation?.isCurrentLocation == true

        let authorized = await notificationsAuthorized()
        var pendingContent: (title: String, body: String)?

        let logic = NotificationWorkerLogic(
            getSavedLocations: { locations },
            getActiveIndex: { activeIndex },
            getUnits: { [preferences] in
                WeatherUnitsResolver.resolve(override: preferences.unitOverride)
            },
            fetchCurrentWeather: { [preferences, weatherRepository] units, label, latitude, longitude in
                let result = await weatherRepository.fetchCurrentWeather(
                    units: units,
                    locationLabel: usesApiCityName ? "" : label,
                    cityQuery: latitude == nil || longitude == nil ? label : nil,
                    latitude: latitude,
                    longitude: longitude
                )
                if case .success(let weather) = result, let cacheKey {
                    preferences.setCachedWeather(weather, for: cacheKey)
                }
                return result
            },
            fetchForecast: { [preferences, weatherRepository] units, label, latitude, longitude in
                let result = await weatherRepository.fetchForecast(
                    units: units,
                    cityQuery: latitude == nil || longitude == nil ? label : nil,
                    latitude: latitude,
                    longitude: longitude
                )
                if case .success(let days) = result, let cacheKey {
                    preferences.setCachedForecast(days, for: cacheKey)
                }
                return result
            },
            hasNotificationPermission: { authorized },
            postNotification: { title, body in pendingContent = (title, body) }
        )

        let result = await logic.doWork()
        if let pendingContent {
            await scheduleNotifications(pendingContent.title, pendingContent.body)
        }
        return result
    }
}
