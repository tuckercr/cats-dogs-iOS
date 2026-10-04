import SwiftUI

/// How the cat and dog react on the home screen, derived from the current conditions.
enum PetMood: CaseIterable {
    case sunny, cloudy, rain, storm, snow, hot, cold, night

    static let hotThresholdC = 30.0
    static let coldThresholdC = 0.0

    /// Precipitation and storms win over temperature, temperature extremes win over time of day,
    /// and an OpenWeatherMap icon ending in "n" means night.
    static func forConditions(conditionMain: String, iconCode: String, temperatureC: Double) -> PetMood {
        switch conditionMain.lowercased() {
        case "thunderstorm": return .storm
        case "snow": return .snow
        case "rain", "drizzle": return .rain
        default:
            if temperatureC >= hotThresholdC { return .hot }
            if temperatureC <= coldThresholdC { return .cold }
            if iconCode.hasSuffix("n") { return .night }
            if conditionMain.caseInsensitiveCompare("clear") == .orderedSame { return .sunny }
            return .cloudy
        }
    }

    /// The hero card background. It keeps this light palette in dark mode too, so text on it
    /// always uses `ink`.
    var skyColor: Color {
        switch self {
        case .sunny: Color(hex: 0xFAC775)
        case .cloudy: Color(hex: 0xB3DDF2)
        case .rain: Color(hex: 0x81C7EC)
        case .storm: Color(hex: 0x9FB3C8)
        case .snow: Color(hex: 0xE6F1FB)
        case .hot: Color(hex: 0xF5C4B3)
        case .cold: Color(hex: 0xCFE3F5)
        case .night: Color(hex: 0x3C4A78)
        }
    }

    var ink: Color {
        self == .night ? Color(hex: 0xF1EFE8) : Color(hex: 0x0C447C)
    }

    /// Captions in the pets' voice. One is picked per day so it varies without changing on refresh.
    var captions: [String] {
        switch self {
        case .sunny: [
            "Perfect walkies weather! Off we go.",
            "The cat has claimed the sunniest windowsill.",
            "Sunshine and tail wags all round.",
        ]
        case .cloudy: [
            "A bit grey, but the dog is still keen for a walk.",
            "Nap weather, says the cat.",
            "No sun, no problem. Still time for a stroll.",
        ]
        case .rain: [
            "The dog wants puddles. The cat wants a towel.",
            "Grab a raincoat. The cat is NOT going out in this.",
            "Wet paws ahead. Keep a towel by the door.",
        ]
        case .storm: [
            "Thunder! The cat is under the bed. Keep pets inside.",
            "Stormy out there. Sofa cuddles today.",
        ]
        case .snow: [
            "Snow zoomies, then straight back to the blanket.",
            "Wipe those paws when you come in.",
        ]
        case .hot: [
            "Too hot for paws on the pavement. Walk early or late.",
            "Fresh water bowls today. It is a scorcher.",
        ]
        case .cold: [
            "Brrr. Short walks and warm blankets.",
            "Coat weather for small dogs today.",
        ]
        case .night: [
            "Both are curled up asleep. Shh.",
            "Quiet night. Time for one last stroll before bed?",
        ]
        }
    }

    func caption(on date: Date = Date(), calendar: Calendar = .current) -> String {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return captions[dayOfYear % captions.count]
    }
}
