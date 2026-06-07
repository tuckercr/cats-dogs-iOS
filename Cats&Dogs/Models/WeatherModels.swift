import Foundation

struct CurrentWeather: Equatable {
    let cityName: String
    let conditionMain: String
    let description: String
    let iconCode: String
    let temperature: Double
    let feelsLike: Double
    let humidityPercent: Int
    let windSpeed: Double
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
    let units: WeatherUnits
}
