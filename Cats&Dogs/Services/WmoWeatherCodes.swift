import Foundation

/// Maps Open-Meteo's WMO weather codes onto the OpenWeatherMap-style condition, description and
/// icon code the rest of the app (icons, pet moods) already understands.
/// Reference: https://open-meteo.com/en/docs (WMO Weather interpretation codes).
enum WmoWeatherCodes {
    struct Condition: Equatable {
        let main: String
        let description: String
        let iconCode: String
    }

    static func condition(_ code: Int, isDay: Bool) -> Condition {
        let (main, description, icon): (String, String, String) = switch code {
        case 0: ("Clear", "clear sky", "01")
        case 1: ("Clouds", "mainly clear", "02")
        case 2: ("Clouds", "partly cloudy", "03")
        case 3: ("Clouds", "overcast", "04")
        case 45, 48: ("Fog", "fog", "50")
        case 51, 53, 55: ("Drizzle", "drizzle", "09")
        case 56, 57: ("Drizzle", "freezing drizzle", "09")
        case 61: ("Rain", "light rain", "10")
        case 63: ("Rain", "moderate rain", "10")
        case 65: ("Rain", "heavy rain", "10")
        case 66, 67: ("Rain", "freezing rain", "13")
        case 71: ("Snow", "light snow", "13")
        case 73: ("Snow", "moderate snow", "13")
        case 75: ("Snow", "heavy snow", "13")
        case 77: ("Snow", "snow grains", "13")
        case 80, 81: ("Rain", "rain showers", "09")
        case 82: ("Rain", "violent rain showers", "09")
        case 85, 86: ("Snow", "snow showers", "13")
        case 95: ("Thunderstorm", "thunderstorm", "11")
        case 96, 99: ("Thunderstorm", "thunderstorm with hail", "11")
        default: ("Clouds", "cloudy", "03")
        }
        return Condition(main: main, description: description, iconCode: icon + (isDay ? "d" : "n"))
    }
}
