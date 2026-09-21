import Foundation

enum UnitOverride: String, Codable, CaseIterable {
    case system
    case metric
    case imperial
}

enum WeatherUnitsResolver {
    static func resolve(override: UnitOverride) -> WeatherUnits {
        switch override {
        case .metric: .metric
        case .imperial: .imperial
        case .system: WeatherUnits.current
        }
    }
}
