import Foundation

enum WeatherUnits: String, Codable {
    case metric
    case imperial

    var apiValue: String { rawValue }

    /// Converts a temperature in these units to Celsius.
    func toCelsius(_ value: Double) -> Double {
        switch self {
        case .metric: value
        case .imperial: (value - 32) * 5 / 9
        }
    }

    /// Converts a Celsius temperature to these units.
    func fromCelsius(_ celsius: Double) -> Double {
        switch self {
        case .metric: celsius
        case .imperial: celsius * 9 / 5 + 32
        }
    }

    static var current: WeatherUnits {
        fromRegionCode(Locale.current.region?.identifier ?? "")
    }

    /// Fallback when regional temperature preference is unavailable: US territories → imperial; otherwise metric.
    static func fromRegionCode(_ regionCode: String) -> WeatherUnits {
        let country = regionCode.uppercased()
        let imperialCountries: Set<String> = ["US", "PR", "GU", "VI", "AS", "MP", "UM"]
        return imperialCountries.contains(country) ? .imperial : .metric
    }
}
