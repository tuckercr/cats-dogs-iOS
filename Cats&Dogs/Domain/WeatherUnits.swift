import Foundation

enum WeatherUnits: String {
    case metric
    case imperial

    var apiValue: String { rawValue }

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
