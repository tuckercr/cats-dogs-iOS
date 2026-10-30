import Foundation

/// The air quality right now: an index on the scale the city uses (Europe's, or the US one
/// everywhere else), and the pollutant behind it. Same rules as Android's `AirQuality`.
struct AirQuality: Equatable, Sendable {
    enum Scale: Equatable, Sendable {
        case us, european

        /// Europe's index for cities on a European clock, the US one everywhere else.
        static func forTimeZone(_ identifier: String?) -> Scale {
            identifier?.hasPrefix("Europe/") == true ? .european : .us
        }

        /// Where each of the six bands starts, and where the last one is drawn to end.
        var bandEdges: [Double] {
            switch self {
            case .us: [0, 50, 100, 150, 200, 300, 500]
            case .european: [0, 20, 40, 60, 80, 100, 150]
            }
        }

        var bandNames: [String] {
            switch self {
            // "Unhealthy for sensitive groups" doesn't fit on a tile.
            case .us: ["Good", "Moderate", "Poor for some", "Unhealthy", "Very unhealthy", "Hazardous"]
            case .european: ["Good", "Fair", "Moderate", "Poor", "Very poor", "Extremely poor"]
            }
        }
    }

    enum Pollutant: CaseIterable, Sendable {
        case fineParticles, coarseParticles, ozone, nitrogenDioxide, sulphurDioxide, carbonMonoxide

        var name: String {
            switch self {
            case .fineParticles: "fine particles"
            case .coarseParticles: "coarse particles"
            case .ozone: "ozone"
            case .nitrogenDioxide: "nitrogen dioxide"
            case .sulphurDioxide: "sulphur dioxide"
            case .carbonMonoxide: "carbon monoxide"
            }
        }
    }

    /// From this band up (US "Unhealthy", Europe's "Poor") an hour is no good for a walk.
    static let badAirBand = 3

    let index: Int
    let scale: Scale
    /// The pollutant with the highest sub-index; nil when none were reported.
    let mainPollutant: Pollutant?

    /// 0 (good) to 5 (the worst band).
    var band: Int {
        let edges = scale.bandEdges
        return (1 ..< edges.count - 1).last { Double(index) > edges[$0] } ?? 0
    }

    var bandName: String { scale.bandNames[band] }

    /// Where the index sits along the six equal bands of the tile's bar, 0 to 1.
    var barPosition: Double {
        let edges = scale.bandEdges
        let within = (Double(index) - edges[band]) / (edges[band + 1] - edges[band])
        return min(max((Double(band) + within) / 6, 0), 1)
    }

    var pollutantLine: String? {
        mainPollutant.map { "Mostly \($0.name)" }
    }

    /// What the air means for a walk, or for people when there's no dog.
    func line(hasDog: Bool) -> String {
        if hasDog {
            return switch band {
            case 0: "Good air for a long walk"
            case 1: "Fine for most walks"
            case 2: "Short walks for older and flat-faced dogs"
            case 3, 4: "Potty breaks only today"
            default: "Stay in. Potty breaks only"
            }
        }
        return switch band {
        case 0: "Fresh air all round"
        case 1: "Fine for most people"
        case 2: "Sensitive people should take it easy"
        case 3, 4: "Limit time outdoors"
        default: "Stay indoors"
        }
    }

    /// Picks the scale for the city and the pollutant with the highest sub-index. Nil without an index.
    static func from(_ response: AirQualityResponse) -> AirQuality? {
        let scale = Scale.forTimeZone(response.timezone)
        let current = response.current
        let index: Int?
        let subIndices: [(Pollutant, Int?)]
        switch scale {
        case .us:
            index = current.usAqi
            subIndices = [
                (.fineParticles, current.usAqiPm25), (.coarseParticles, current.usAqiPm10),
                (.ozone, current.usAqiOzone), (.nitrogenDioxide, current.usAqiNitrogenDioxide),
                (.sulphurDioxide, current.usAqiSulphurDioxide), (.carbonMonoxide, current.usAqiCarbonMonoxide),
            ]
        case .european:
            index = current.europeanAqi
            subIndices = [
                (.fineParticles, current.europeanAqiPm25), (.coarseParticles, current.europeanAqiPm10),
                (.ozone, current.europeanAqiOzone), (.nitrogenDioxide, current.europeanAqiNitrogenDioxide),
                (.sulphurDioxide, current.europeanAqiSulphurDioxide),
            ]
        }
        guard let index else { return nil }
        // The first listed wins a tie.
        var main: (pollutant: Pollutant, value: Int)?
        for (pollutant, value) in subIndices {
            if let value, value > (main?.value ?? .min) { main = (pollutant, value) }
        }
        return AirQuality(index: index, scale: scale, mainPollutant: main?.pollutant)
    }
}

/// Open-Meteo's hourly air quality forecast, for the walk planner.
struct AirQualityHourlyResponse: Decodable, Sendable {
    let timezone: String?
    let hourly: Hourly

    struct Hourly: Decodable, Sendable {
        let time: [Int]
        let usAqi: [Int?]?
        let europeanAqi: [Int?]?

        enum CodingKeys: String, CodingKey {
            case time
            case usAqi = "us_aqi"
            case europeanAqi = "european_aqi"
        }
    }

    /// Each hour's band on the city's scale, by the hour's start in Unix seconds.
    var bandsByHour: [Int: Int] {
        let scale = AirQuality.Scale.forTimeZone(timezone)
        let indices = (scale == .european ? hourly.europeanAqi : hourly.usAqi) ?? []
        var bands: [Int: Int] = [:]
        for (time, index) in zip(hourly.time, indices) {
            if let index { bands[time] = AirQuality(index: index, scale: scale, mainPollutant: nil).band }
        }
        return bands
    }
}

/// Open-Meteo's air quality response, only the fields the tile uses.
struct AirQualityResponse: Decodable, Sendable {
    let timezone: String?
    let current: Current

    struct Current: Decodable, Sendable {
        let usAqi: Int?
        let usAqiPm25: Int?
        let usAqiPm10: Int?
        let usAqiOzone: Int?
        let usAqiNitrogenDioxide: Int?
        let usAqiSulphurDioxide: Int?
        let usAqiCarbonMonoxide: Int?
        let europeanAqi: Int?
        let europeanAqiPm25: Int?
        let europeanAqiPm10: Int?
        let europeanAqiOzone: Int?
        let europeanAqiNitrogenDioxide: Int?
        let europeanAqiSulphurDioxide: Int?

        enum CodingKeys: String, CodingKey, CaseIterable {
            case usAqi = "us_aqi"
            case usAqiPm25 = "us_aqi_pm2_5"
            case usAqiPm10 = "us_aqi_pm10"
            case usAqiOzone = "us_aqi_ozone"
            case usAqiNitrogenDioxide = "us_aqi_nitrogen_dioxide"
            case usAqiSulphurDioxide = "us_aqi_sulphur_dioxide"
            case usAqiCarbonMonoxide = "us_aqi_carbon_monoxide"
            case europeanAqi = "european_aqi"
            case europeanAqiPm25 = "european_aqi_pm2_5"
            case europeanAqiPm10 = "european_aqi_pm10"
            case europeanAqiOzone = "european_aqi_ozone"
            case europeanAqiNitrogenDioxide = "european_aqi_nitrogen_dioxide"
            case europeanAqiSulphurDioxide = "european_aqi_sulphur_dioxide"
        }
    }
}
