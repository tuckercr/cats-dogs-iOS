import Foundation

struct CurrentWeather: Equatable {
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
}

struct HourlySlot: Equatable, Identifiable {
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

struct DayForecast: Equatable, Identifiable {
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
