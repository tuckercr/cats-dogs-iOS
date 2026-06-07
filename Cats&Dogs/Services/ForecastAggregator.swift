import Foundation

enum ForecastAggregator {
    struct Slot {
        let epochSeconds: Int
        let temperature: Double
        let feelsLike: Double
        let conditionMain: String
        let description: String
        let iconCode: String
    }

    static func aggregate(
        slots: [Slot],
        timeZone: TimeZone = .current,
        units: WeatherUnits
    ) -> [DayForecast] {
        guard !slots.isEmpty else { return [] }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let grouped = Dictionary(grouping: slots) { slot -> Date in
            let date = Date(timeIntervalSince1970: TimeInterval(slot.epochSeconds))
            return calendar.startOfDay(for: date)
        }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateFormat = "EEE, MMM d"

        return grouped.keys.sorted().map { dayStart in
            let daySlots = grouped[dayStart] ?? []
            let noonMinutes = 12 * 60
            let representative = daySlots.min { lhs, rhs in
                minutesFromNoon(lhs.epochSeconds, calendar: calendar) <
                    minutesFromNoon(rhs.epochSeconds, calendar: calendar)
            }!

            return DayForecast(
                dateLabel: formatter.string(from: dayStart),
                conditionMain: representative.conditionMain,
                description: representative.description.weatherSentenceCased,
                iconCode: representative.iconCode,
                temperature: representative.temperature,
                feelsLike: representative.feelsLike,
                units: units
            )
        }
    }

    private static func minutesFromNoon(_ epochSeconds: Int, calendar: Calendar) -> Int {
        let date = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return abs(hour * 60 + minute - 12 * 60)
    }
}
