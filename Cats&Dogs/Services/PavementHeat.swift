import Foundation

/// Rough estimate of sun-baked asphalt temperature, in degrees Celsius.
///
/// Dark pavement in direct sun runs far hotter than the air: at 25 C air and strong sun it reaches
/// about 50 C, hot enough to burn paws. A heating term proportional to incoming solar radiation is
/// added, capped so cloudless noon sun adds at most `maxSolarGainC`. At night, or with no sun,
/// pavement settles to the air temperature.
///
/// Pavement doesn't jump to that temperature: it warms through the morning after a cold night and
/// keeps some heat into the evening. `series` follows that, hour by hour. Same model as Android's
/// `PavementHeat.kt`.
enum PavementHeat {
    private static let gainCPerWatt = 0.035
    private static let maxSolarGainC = 35.0

    /// How far pavement moves toward the temperature the sun and air are pushing it to in one hour:
    /// dark asphalt heats quickly in the sun and gives the heat back more slowly.
    private static let heatingPerHour = 0.6
    private static let coolingPerHour = 0.4

    /// The temperature the pavement would settle at in this air and sun.
    static func estimateC(airC: Double, shortwaveRadiationWm2: Double?, isDay: Bool) -> Double {
        let radiation = shortwaveRadiationWm2 ?? 0
        guard isDay, radiation > 0 else { return airC }
        return airC + min(radiation * gainCPerWatt, maxSolarGainC)
    }

    /// Pavement temperature for each hour of an hourly series (consecutive hours, as Open-Meteo sends
    /// from midnight), nil where the air temperature is missing.
    ///
    /// Open-Meteo's radiation at time t is the average over the hour *before* t, so the hour that
    /// starts at t uses the value at t + 1 h (the last hour, with nothing after it, keeps its own).
    /// The first hour starts at its settled temperature; each later hour moves part of the way from
    /// the previous hour's pavement towards its own settled temperature.
    static func series(airC: [Double?], shortwaveRadiationWm2: [Double?], isDay: [Bool]) -> [Double?] {
        var pavement: Double?
        return airC.indices.map { i in
            guard let air = airC[i] else { return nil }
            let radiation = i + 1 < shortwaveRadiationWm2.count
                ? shortwaveRadiationWm2[i + 1]
                : (i < shortwaveRadiationWm2.count ? shortwaveRadiationWm2[i] : nil)
            // The sun is up for some of this hour if it is at either end.
            let day = (i < isDay.count && isDay[i]) || (i + 1 < isDay.count && isDay[i + 1])
            let settled = estimateC(airC: air, shortwaveRadiationWm2: radiation, isDay: day)
            let next: Double
            if let previous = pavement {
                next = previous + (settled - previous) * (settled > previous ? heatingPerHour : coolingPerHour)
            } else {
                next = settled
            }
            pavement = next
            return next
        }
    }
}
