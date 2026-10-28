import Foundation

enum NotificationWorkerResult: Equatable {
    case success
    case retry
}

struct NotificationWorkerLogic {
    let getSavedLocations: () async -> [SavedLocation]
    let getUnits: () async -> WeatherUnits
    let fetchCurrentWeather: (
        _ units: WeatherUnits,
        _ label: String,
        _ latitude: Double?,
        _ longitude: Double?
    ) async -> Result<CurrentWeather, Error>
    let fetchForecast: (
        _ units: WeatherUnits,
        _ label: String,
        _ latitude: Double?,
        _ longitude: Double?
    ) async -> Result<[DayForecast], Error>
    let hasNotificationPermission: () -> Bool
    /// The caches are fresh and notifications are allowed: time to replan them.
    let onRefreshed: () -> Void

    /// Fetches the notification city's weather and forecast (the fetch callbacks cache them), then calls
    /// `onRefreshed`. Retries when the current weather can't be fetched.
    func doWork() async -> NotificationWorkerResult {
        guard let location = await getSavedLocations().notificationLocation else { return .success }

        let units = await getUnits()
        let weatherResult = await fetchCurrentWeather(
            units,
            location.label,
            location.latitude,
            location.longitude
        )
        guard case .success = weatherResult else { return .retry }

        _ = await fetchForecast(
            units,
            location.label,
            location.latitude,
            location.longitude
        )

        guard hasNotificationPermission() else { return .success }
        onRefreshed()
        return .success
    }
}
