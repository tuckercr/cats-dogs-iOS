import Foundation

/// Rough estimate of sun-baked asphalt temperature, in degrees Celsius.
///
/// Dark pavement in direct sun runs far hotter than the air: at 25 C air and strong sun it reaches
/// about 50 C, hot enough to burn paws. A heating term proportional to incoming solar radiation is
/// added, capped so cloudless noon sun adds at most `maxSolarGainC`. At night, or with no sun,
/// pavement sits near the air temperature.
enum PavementHeat {
    private static let gainCPerWatt = 0.035
    private static let maxSolarGainC = 35.0

    static func estimateC(airC: Double, shortwaveRadiationWm2: Double?, isDay: Bool) -> Double {
        let radiation = shortwaveRadiationWm2 ?? 0
        guard isDay, radiation > 0 else { return airC }
        return airC + min(radiation * gainCPerWatt, maxSolarGainC)
    }
}
