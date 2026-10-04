import Foundation

enum NotificationWorkerResult: Equatable {
    case success
    case retry
}

struct NotificationWorkerLogic {
    let getSavedLocations: () async -> [SavedLocation]
    let getActiveIndex: () async -> Int
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
    let postNotification: (_ title: String, _ body: String) -> Void
    /// Overridable for tests; nil means today's label on this device.
    /// Today's label in the city's time zone. Overridable for tests; nil means the real date.
    var todayLabel: ((TimeZone) -> String)? = nil

    func doWork() async -> NotificationWorkerResult {
        let locations = await getSavedLocations()
        guard !locations.isEmpty else { return .success }

        let activeIndex = await getActiveIndex()
        guard let location = locations[safe: activeIndex] else { return .success }

        let units = await getUnits()
        let weatherResult = await fetchCurrentWeather(
            units,
            location.label,
            location.latitude,
            location.longitude
        )
        guard case .success(let weather) = weatherResult else { return .retry }

        let forecastResult = await fetchForecast(
            units,
            location.label,
            location.latitude,
            location.longitude
        )
        let todayForecast = (try? forecastResult.get()).flatMap {
            forecastForToday(in: $0, timeZone: weather.timeZone, todayLabel: todayLabel?(weather.timeZone))
        }

        guard hasNotificationPermission() else { return .success }

        let content = buildNotificationContent(weather: weather, todayForecast: todayForecast)
        postNotification(content.title, content.body)
        return .success
    }
}

/// `/forecast` starts at the next 3-hour slot, so late in the day its first entry is tomorrow, and a
/// stale cache starts with yesterday. Only an entry that is actually today may supply the high/low.
func forecastForToday(
    in days: [DayForecast],
    timeZone: TimeZone,
    todayLabel: String? = nil
) -> DayForecast? {
    let todayLabel = todayLabel ?? WeatherFormatting.todayLabel(timeZone: timeZone)
    return days.first { $0.dateLabel == todayLabel }
}

func buildNotificationContent(
    weather: CurrentWeather,
    todayForecast: DayForecast?
) -> (title: String, body: String) {
    let tempHigh = Int((todayForecast?.tempMax ?? weather.tempMax).rounded())
    let tempLow = Int((todayForecast?.tempMin ?? weather.tempMin).rounded())
    let description = weather.description
        .split(separator: " ")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
    let title = "\(Int(weather.temperature.rounded()))° in \(weather.cityName)"
    let body = "\(tempHigh)°/\(tempLow)° • \(description)"
    return (title, body)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
