import Foundation

/// The judgement calls behind the pets' moods and the walk card, tunable from Remote Config. All
/// temperatures are Celsius whatever units the user picked.
struct PetWeatherThresholds: Equatable {
    /// Asphalt this hot burns paws in under a minute (about 125 F).
    var hotPavementC: Double
    /// A slot with this chance of rain or more isn't suggested for a walk.
    var maxRainChance: Int
    var comfortC: ClosedRange<Double>
    /// Nobody wants walk advice for 2 AM: only suggest slots in these local hours.
    var walkHours: ClosedRange<Int>
    var petHotC: Double
    var petColdC: Double

    static let standard = PetWeatherThresholds(
        hotPavementC: 52,
        maxRainChance: 30,
        comfortC: 3 ... 27,
        walkHours: 7 ... 20,
        petHotC: 30,
        petColdC: 0
    )

    static let hotPavementRangeC = 40.0 ... 70.0
    static let maxRainChanceRange = 0 ... 100
    static let comfortMinRangeC = -20.0 ... 20.0
    static let comfortMaxRangeC = 15.0 ... 40.0
    static let walkHourRange = 0 ... 23
    static let petHotRangeC = 20.0 ... 45.0
    static let petColdRangeC = -20.0 ... 10.0

    /// Builds thresholds from raw Remote Config values. A value that's missing or out of range falls
    /// back to the standard one, and a pair that ends up inverted falls back as a pair, so a console
    /// typo can never produce nonsense advice.
    static func validated(
        hotPavementC: Double? = nil,
        maxRainChance: Int? = nil,
        comfortMinC: Double? = nil,
        comfortMaxC: Double? = nil,
        walkHoursStart: Int? = nil,
        walkHoursEnd: Int? = nil,
        petHotC: Double? = nil,
        petColdC: Double? = nil
    ) -> PetWeatherThresholds {
        let standard = Self.standard
        let comfortMin = pick(comfortMinC, in: comfortMinRangeC, or: standard.comfortC.lowerBound)
        let comfortMax = pick(comfortMaxC, in: comfortMaxRangeC, or: standard.comfortC.upperBound)
        let hoursStart = pick(walkHoursStart, in: walkHourRange, or: standard.walkHours.lowerBound)
        let hoursEnd = pick(walkHoursEnd, in: walkHourRange, or: standard.walkHours.upperBound)
        let hot = pick(petHotC, in: petHotRangeC, or: standard.petHotC)
        let cold = pick(petColdC, in: petColdRangeC, or: standard.petColdC)
        return PetWeatherThresholds(
            hotPavementC: pick(hotPavementC, in: hotPavementRangeC, or: standard.hotPavementC),
            maxRainChance: pick(maxRainChance, in: maxRainChanceRange, or: standard.maxRainChance),
            comfortC: comfortMin < comfortMax ? comfortMin ... comfortMax : standard.comfortC,
            walkHours: hoursStart < hoursEnd ? hoursStart ... hoursEnd : standard.walkHours,
            petHotC: cold < hot ? hot : standard.petHotC,
            petColdC: cold < hot ? cold : standard.petColdC
        )
    }

    private static func pick<Value: Comparable>(_ value: Value?, in range: ClosedRange<Value>, or fallback: Value) -> Value {
        guard let value, range.contains(value) else { return fallback }
        return value
    }
}
