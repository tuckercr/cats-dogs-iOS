import Foundation

struct CurrentWeatherResponse: Decodable {
    let name: String
    let weather: [WeatherDescDTO]
    let main: MainDTO
    let wind: WindDTO
}

struct ForecastResponse: Decodable {
    let list: [ForecastListItemDTO]
}

struct ForecastListItemDTO: Decodable {
    let dt: Int
    let main: MainDTO
    let weather: [WeatherDescDTO]
}

struct WeatherDescDTO: Decodable {
    let main: String
    let description: String
    let icon: String
}

struct MainDTO: Decodable {
    let temp: Double
    let feelsLike: Double
    let humidity: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case humidity
    }
}

struct WindDTO: Decodable {
    let speed: Double
}

struct GeocodingDirectDTO: Decodable {
    let name: String
    let lat: Double
    let lon: Double
    let country: String
    let state: String?
}

struct OpenWeatherErrorResponse: Decodable {
    let message: String?
}
