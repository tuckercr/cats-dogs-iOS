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
        case .metric: String(format: "%.1f m/s", speed)
        case .imperial: String(format: "%.1f mph", speed)
        }
    }

    static func pressure(_ hpa: Int) -> String {
        "\(hpa) hPa"
    }

    static func visibility(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", Double(meters) / 1000.0)
        }
        return "\(meters) m"
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
}
