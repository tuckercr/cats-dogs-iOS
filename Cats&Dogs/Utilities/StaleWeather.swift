import Foundation

/// Handling of cached weather that's on screen because a refresh failed. Same rules as Android's
/// `util/StaleWeather.kt`.
enum StaleWeather {
    /// How old cached current conditions can be and still be shown as "now" when a refresh fails.
    /// Older than this, the screen shows the cached forecast for the current hour instead.
    static let showAsNowFor: TimeInterval = 3 * 60 * 60

    /// How often old weather is re-checked against the cutoff while a refresh keeps failing.
    static let recheckInterval: Duration = .seconds(5 * 60)

    /// The longest forecast slot (OpenWeather's 3-hourly ones), for when the last slot ends.
    private static let longestSlot = 3 * 60 * 60

    /// True when this reading is too old to show as the current conditions; unknown age counts as fresh.
    static func isTooOldToShowAsNow(_ weather: CurrentWeather, now: Date) -> Bool {
        guard let observedAt = weather.observedAtEpoch else { return false }
        return now.timeIntervalSince1970 - TimeInterval(observedAt) > showAsNowFor
    }

    /// The cached forecast's slot in progress at `now`, as current conditions: temperature, conditions,
    /// wind and humidity from the forecast, today's high and low, and everything else (city, time zone,
    /// sunrise and sunset, observation time) from `weather`. Visibility isn't forecast, so it's
    /// cleared. Nil when the forecast doesn't cover now (it ran out, or has no timestamps).
    static func forecastAsCurrent(_ weather: CurrentWeather, forecast: [DayForecast], now: Date) -> CurrentWeather? {
        let nowEpoch = Int(now.timeIntervalSince1970)
        let slots = forecast
            .flatMap { day in day.hourlySlots.map { (day, $0) } }
            .filter { $0.1.epochSeconds != nil }
            .sorted { $0.1.epochSeconds! < $1.1.epochSeconds! }
        guard let index = slots.lastIndex(where: { $0.1.epochSeconds! <= nowEpoch }) else { return nil }
        let (day, slot) = slots[index]
        // The slot must still be in progress: before the next one starts, or for the last slot,
        // within the longest slot length.
        let end = index + 1 < slots.count ? slots[index + 1].1.epochSeconds! : slot.epochSeconds! + longestSlot
        guard nowEpoch < end else { return nil }
        return CurrentWeather(
            cityName: weather.cityName,
            conditionMain: conditionMain(forIcon: slot.iconCode),
            description: slot.description,
            iconCode: slot.iconCode,
            temperature: slot.temperature,
            feelsLike: slot.feelsLike,
            tempMin: day.tempMin,
            tempMax: day.tempMax,
            humidityPercent: slot.humidity,
            pressureHpa: slot.pressure,
            windSpeed: slot.windSpeed,
            windDeg: slot.windDeg,
            visibilityMeters: nil,
            cloudPercent: weather.cloudPercent,
            units: slot.units,
            sunriseEpoch: weather.sunriseEpoch,
            sunsetEpoch: weather.sunsetEpoch,
            timezoneOffsetSeconds: weather.timezoneOffsetSeconds,
            observedAtEpoch: weather.observedAtEpoch
        )
    }

    /// OpenWeather's condition group for an icon code ("10d" is rain), as `CurrentWeather.conditionMain`.
    static func conditionMain(forIcon iconCode: String) -> String {
        switch iconCode.prefix(2) {
        case "01": "Clear"
        case "02", "03", "04": "Clouds"
        case "09", "10": "Rain"
        case "11": "Thunderstorm"
        case "13": "Snow"
        case "50": "Mist"
        default: "Clouds"
        }
    }

    /// When `weather` was observed: "10:10 AM" today, "yesterday at 10:10 AM", or "Sat at 10:10 AM",
    /// in the city's own date. Nil when the observation time isn't known.
    static func readingTime(_ weather: CurrentWeather, now: Date) -> String? {
        guard let observedAt = weather.observedAtEpoch else { return nil }
        let time = WeatherFormatting.epochTime(observedAt, timeZone: weather.timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = weather.timeZone
        let then = Date(timeIntervalSince1970: TimeInterval(observedAt))
        if calendar.isDate(then, inSameDayAs: now) { return time }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(then, inSameDayAs: yesterday) {
            return "yesterday at \(time)"
        }
        let formatter = DateFormatter()
        formatter.timeZone = weather.timeZone
        formatter.locale = .current
        formatter.dateFormat = "EEE"
        return "\(formatter.string(from: then)) at \(time)"
    }
}
