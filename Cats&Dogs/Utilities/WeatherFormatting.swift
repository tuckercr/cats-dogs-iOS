import Foundation

enum WeatherFormatting {
    static func temperature(_ value: Double, units: WeatherUnits) -> String {
        switch units {
        case .metric: String(format: "%.1f °C", value)
        case .imperial: String(format: "%.1f °F", value)
        }
    }

    static func wind(_ speed: Double, units: WeatherUnits) -> String {
        switch units {
        case .metric: isCalm(speed) ? "0 m/s" : String(format: "%.1f m/s", speed)
        case .imperial: isCalm(speed) ? "0 mph" : String(format: "%.1f mph", speed)
        }
    }

    /// Speed and compass direction, without a direction when it's calm ("0 mph N" means nothing).
    static func windWithDirection(_ speed: Double, deg: Int, units: WeatherUnits) -> String {
        isCalm(speed) ? wind(speed, units: units) : "\(wind(speed, units: units))  \(windDirection(deg))"
    }

    /// A speed that would show as "0.0": written as a plain 0, with no direction.
    static func isCalm(_ speed: Double) -> Bool { speed < 0.05 }

    /// OpenWeather reports visibility up to 10 km and no further, so 10 km means "at least 10 km".
    /// Converted, that read as a precise and poor-looking 6.2 mi (US sources cap at 10 mi instead).
    static func visibility(_ meters: Int, inMiles: Bool = false) -> String {
        if meters >= 10_000 {
            return "Clear"
        }
        if inMiles {
            return String(format: "%.1f mi", Double(meters) / 1609.344)
        }
        if meters >= 1000 {
            return String(format: "%.1f km", Double(meters) / 1000.0)
        }
        return "\(meters) m"
    }

    /// Whether distances (visibility) read in miles: the app's unit choice, or for "Use system
    /// setting" the system's measurement system (Settings › General › Language & Region), where the
    /// US and UK use miles.
    static func usesMiles(override: UnitOverride, locale: Locale = .current) -> Bool {
        switch override {
        case .metric: false
        case .imperial: true
        case .system: locale.measurementSystem != .metric
        }
    }

    static func windDirection(_ deg: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[((deg + 22) / 45) % 8]
    }

    static func todayLabel(timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date())
    }

    /// UV index with the WHO exposure category, e.g. "6 (High)".
    static func uvIndex(_ uv: Double) -> String {
        let value = Int(uv.rounded())
        let level = switch value {
        case ...2: "Low"
        case 3...5: "Moderate"
        case 6...7: "High"
        case 8...10: "Very high"
        default: "Extreme"
        }
        return "\(value) (\(level))"
    }

    static func epochTime(_ epochSeconds: Int, timeZone: TimeZone = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
