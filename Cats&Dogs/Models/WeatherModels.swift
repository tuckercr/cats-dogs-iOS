import Foundation

struct CurrentWeather: Codable, Equatable {
    let cityName: String
    let conditionMain: String
    let description: String
    let iconCode: String
    let temperature: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let humidityPercent: Int
    let pressureHpa: Int
    let windSpeed: Double
    let windDeg: Int
    let visibilityMeters: Int?
    let cloudPercent: Int
    let units: WeatherUnits
    let sunriseEpoch: Int?
    let sunsetEpoch: Int?
    /// The city's offset from UTC, so sunrise and sunset can be shown in its local time.
    var timezoneOffsetSeconds: Int? = nil
    /// When OpenWeather took this reading, in epoch seconds; nil in data cached before it was recorded.
    /// Shown as "Showing weather from ..." when a refresh fails and cached data stays up.
    var observedAtEpoch: Int? = nil

    var timeZone: TimeZone {
        timezoneOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }
}

struct HourlySlot: Codable, Equatable, Identifiable {
    /// Labels like "3 PM" repeat across days, so prefer the timestamp when there is one.
    var id: String { epochSeconds.map(String.init) ?? timeLabel }
    let timeLabel: String
    let iconCode: String
    let description: String
    let temperature: Double
    let feelsLike: Double
    let windSpeed: Double
    let windDeg: Int
    let humidity: Int
    let pressure: Int
    let units: WeatherUnits
    /// Probability of precipitation as a percentage, 0...100.
    var precipitationChance: Int = 0
    /// UV index (0...11+); nil when the source doesn't provide it.
    var uvIndex: Double? = nil
    /// Estimated sun-baked pavement temperature in `units`; nil when unknown.
    var pavementTemperature: Double? = nil
    /// Hour of day (0...23) in the location's own time zone.
    var localHour: Int? = nil
    var epochSeconds: Int? = nil

    var date: Date? { epochSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
}

struct DayForecast: Codable, Equatable, Identifiable {
    var id: String { dateLabel }
    let dateLabel: String
    let conditionMain: String
    let description: String
    let iconCode: String
    let temperature: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let units: WeatherUnits
    let hourlySlots: [HourlySlot]
    /// Highest probability of precipitation across the day's slots, as a percentage, 0...100.
    var precipitationChance: Int = 0
    /// Peak UV index across the day's slots; nil when the source doesn't provide UV.
    var uvIndexMax: Double? = nil
}

extension Array where Element == HourlySlot {
    /// Drops slots that are already over, keeping the one in progress. Past hours are only removed
    /// when a forecast is downloaded, so a cached forecast, a failed refresh or an app left open for
    /// hours would otherwise start in the past. Keeping from the last slot that started at or before
    /// `now` works for hourly and 3-hourly data alike. Slots without a timestamp are kept.
    func upcoming(from now: Date) -> [HourlySlot] {
        let nowEpoch = Int(now.timeIntervalSince1970)
        guard let current = lastIndex(where: { ($0.epochSeconds ?? .max) <= nowEpoch }) else { return self }
        return Array(self[current...])
    }
}
