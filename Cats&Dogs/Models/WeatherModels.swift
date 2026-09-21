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
    var id: String { timeLabel }
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
}
