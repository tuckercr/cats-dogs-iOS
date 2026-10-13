import Foundation

enum WalkRating: Equatable {
    case great, okay, poor, pawsHot, tooCold
}

/// `bestTimeLabel` is nil when now is a good time, or when there is no good window soon.
/// `pavementNow` is the estimated pavement temperature for the current hour, in the forecast's
/// units, when the source provides it. `bestTimeIsTomorrow` is set when the best time falls on the
/// city's next day, since the label alone ("7 AM") doesn't say which morning.
struct WalkAdvice: Equatable {
    let rating: WalkRating
    let bestTimeLabel: String?
    var pavementNow: Double? = nil
    var bestTimeIsTomorrow = false
}

enum WalkAdvisor {
    private static let maxRainChance = 30
    private static let comfortC = 3.0...27.0
    private static let lookaheadSlots = 24 // a day of hourly slots
    /// 24 three-hourly OpenWeatherMap slots would reach three days out, so the advice is also capped
    /// by time: the best time is always today or tomorrow.
    private static let lookaheadSeconds = 24 * 3600
    /// Asphalt this hot burns paws in under a minute (about 125 F).
    static let pawsHotPavementC = 52.0
    /// Nobody wants walk advice for 2 AM: only suggest slots between 7 AM and 8 PM.
    private static let walkHours = 7...20

    /// Works out when to walk the dog from the current temperature and the upcoming hourly slots
    /// (the first slot is the current or next forecast hour, so it stands in for "now"). Returns nil
    /// when there are no slots yet (forecast loading or failed), since there is nothing to advise on.
    static func advice(
        currentTempC: Double,
        upcoming: [HourlySlot],
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> WalkAdvice? {
        let horizon = Int(now.timeIntervalSince1970) + lookaheadSeconds
        let slots = upcoming.prefix(lookaheadSlots).filter { ($0.epochSeconds ?? 0) <= horizon }
        guard let first = slots.first else { return nil }
        let firstGood = slots.first { isWalkable($0) }
        let pawsHotNow = (pavementC(first) ?? 0) >= pawsHotPavementC
        let rating: WalkRating = if currentTempC >= PetMood.hotThresholdC || pawsHotNow {
            .pawsHot
        } else if currentTempC <= PetMood.coldThresholdC {
            .tooCold
        } else if isWalkable(first) {
            .great
        } else if firstGood != nil {
            .okay
        } else {
            .poor
        }
        let bestSlot = rating == .great ? nil : firstGood
        return WalkAdvice(
            rating: rating,
            bestTimeLabel: bestSlot?.timeLabel,
            pavementNow: first.pavementTemperature,
            bestTimeIsTomorrow: bestSlot.map { isOnALaterDay($0, than: now, in: timeZone) } ?? false
        )
    }

    /// Compared as calendar days in the city's own time zone, not the device's.
    private static func isOnALaterDay(_ slot: HourlySlot, than now: Date, in timeZone: TimeZone) -> Bool {
        guard let epoch = slot.epochSeconds else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return !calendar.isDate(Date(timeIntervalSince1970: TimeInterval(epoch)), inSameDayAs: now)
    }

    private static func isDaytime(_ slot: HourlySlot) -> Bool {
        slot.localHour.map(walkHours.contains) ?? true
    }

    private static func pavementC(_ slot: HourlySlot) -> Double? {
        slot.pavementTemperature.map(slot.units.toCelsius)
    }

    private static func isWalkable(_ slot: HourlySlot) -> Bool {
        isDaytime(slot)
            && (pavementC(slot) ?? 0) < pawsHotPavementC
            && slot.precipitationChance < maxRainChance
            && comfortC.contains(slot.units.toCelsius(slot.temperature))
    }
}
