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
