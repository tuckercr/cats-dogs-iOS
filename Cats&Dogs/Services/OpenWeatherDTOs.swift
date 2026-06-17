import Foundation

struct CurrentWeatherResponse: Decodable {
    let name: String
    let weather: [WeatherDescDTO]
    let main: MainDTO
    let wind: WindDTO
    let visibility: Int?
    let clouds: CloudsDTO?
}

struct CloudsDTO: Decodable {
    let all: Int
}

struct ForecastResponse: Decodable {
    let list: [ForecastListItemDTO]
}

struct ForecastListItemDTO: Decodable {
    let dt: Int
    let main: MainDTO
    let weather: [WeatherDescDTO]
    let wind: WindDTO
}

struct WeatherDescDTO: Decodable {
    let main: String
    let description: String
    let icon: String
}

struct MainDTO: Decodable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let humidity: Int
    let pressure: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case humidity
        case pressure
    }

    init(
        temp: Double,
        feelsLike: Double,
        tempMin: Double = 0,
        tempMax: Double = 0,
        humidity: Int,
        pressure: Int = 0
    ) {
        self.temp = temp
        self.feelsLike = feelsLike
        self.tempMin = tempMin
        self.tempMax = tempMax
        self.humidity = humidity
        self.pressure = pressure
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        temp = try container.decode(Double.self, forKey: .temp)
        feelsLike = try container.decode(Double.self, forKey: .feelsLike)
        tempMin = try container.decodeIfPresent(Double.self, forKey: .tempMin) ?? 0
        tempMax = try container.decodeIfPresent(Double.self, forKey: .tempMax) ?? 0
        humidity = try container.decode(Int.self, forKey: .humidity)
        pressure = try container.decodeIfPresent(Int.self, forKey: .pressure) ?? 0
    }
}

struct WindDTO: Decodable {
    let speed: Double
    let deg: Int

    init(speed: Double, deg: Int = 0) {
        self.speed = speed
        self.deg = deg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speed = try container.decode(Double.self, forKey: .speed)
        deg = try container.decodeIfPresent(Int.self, forKey: .deg) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case speed
        case deg
    }
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
