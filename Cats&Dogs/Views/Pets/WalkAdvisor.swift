import Foundation

enum WalkRating: Equatable {
    case great, okay, poor, pawsHot, tooCold
}

/// `bestTimeLabel` is nil when now is a good time, or when there is no good window soon.
/// `pavementNow` is the estimated pavement temperature for the current hour, in the forecast's
/// units, when the source provides it.
struct WalkAdvice: Equatable {
    let rating: WalkRating
    let bestTimeLabel: String?
    var pavementNow: Double? = nil
}

enum WalkAdvisor {
    private static let lookaheadSlots = 24 // a day of hourly slots

    /// Works out when to walk the dog from the current temperature and the upcoming hourly slots
    /// (the first slot is the current or next forecast hour, so it stands in for "now"). Returns nil
    /// when there are no slots yet (forecast loading or failed), since there is nothing to advise on.
    static func advice(
        currentTempC: Double,
        upcoming: [HourlySlot],
        thresholds: PetWeatherThresholds = .standard
    ) -> WalkAdvice? {
        let slots = Array(upcoming.prefix(lookaheadSlots))
        guard let first = slots.first else { return nil }
        let firstGood = slots.first { isWalkable($0, thresholds) }
        let pawsHotNow = (pavementC(first) ?? 0) >= thresholds.hotPavementC
        let rating: WalkRating = if currentTempC >= thresholds.petHotC || pawsHotNow {
            .pawsHot
        } else if currentTempC <= thresholds.petColdC {
            .tooCold
        } else if isWalkable(first, thresholds) {
            .great
        } else if firstGood != nil {
            .okay
        } else {
            .poor
        }
        let best = rating == .great ? nil : firstGood?.timeLabel
        return WalkAdvice(rating: rating, bestTimeLabel: best, pavementNow: first.pavementTemperature)
    }

    private static func isDaytime(_ slot: HourlySlot, _ thresholds: PetWeatherThresholds) -> Bool {
        slot.localHour.map(thresholds.walkHours.contains) ?? true
    }

    private static func pavementC(_ slot: HourlySlot) -> Double? {
        slot.pavementTemperature.map(slot.units.toCelsius)
    }

    private static func isWalkable(_ slot: HourlySlot, _ thresholds: PetWeatherThresholds) -> Bool {
        isDaytime(slot, thresholds)
            && (pavementC(slot) ?? 0) < thresholds.hotPavementC
            && slot.precipitationChance < thresholds.maxRainChance
            && thresholds.comfortC.contains(slot.units.toCelsius(slot.temperature))
    }
}
