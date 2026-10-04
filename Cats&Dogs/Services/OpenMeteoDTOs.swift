import Foundation

/// Response of Open-Meteo's /v1/forecast with `timeformat=unixtime` and `timezone=auto`.
struct OpenMeteoResponse: Decodable {
    /// The location's offset from UTC, in seconds (`timezone=auto` resolves it from the coordinates).
    var utcOffsetSeconds: Int = 0
    /// IANA zone name (e.g. "Europe/London"), so DST changes inside the forecast window are honoured.
    var timezone: String? = nil
    var hourly = OpenMeteoHourlyDTO()

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone
        case hourly
    }

    init(utcOffsetSeconds: Int = 0, timezone: String? = nil, hourly: OpenMeteoHourlyDTO = OpenMeteoHourlyDTO()) {
        self.utcOffsetSeconds = utcOffsetSeconds
        self.timezone = timezone
        self.hourly = hourly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        utcOffsetSeconds = try container.decodeIfPresent(Int.self, forKey: .utcOffsetSeconds) ?? 0
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        hourly = try container.decodeIfPresent(OpenMeteoHourlyDTO.self, forKey: .hourly) ?? OpenMeteoHourlyDTO()
    }
}

/// Parallel arrays: index i of every list describes the hour starting at `time[i]`.
struct OpenMeteoHourlyDTO: Decodable {
    var time: [Int] = []
    var temperature: [Double?] = []
    var apparentTemperature: [Double?] = []
    var precipitationProbability: [Int?] = []
    var weatherCode: [Int?] = []
    var windSpeed: [Double?] = []
    var windDirection: [Int?] = []
    var relativeHumidity: [Int?] = []
    var seaLevelPressure: [Double?] = []
    var uvIndex: [Double?] = []
    var shortwaveRadiation: [Double?] = []
    var isDay: [Int?] = []

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
        case relativeHumidity = "relative_humidity_2m"
        case seaLevelPressure = "pressure_msl"
        case uvIndex = "uv_index"
        case shortwaveRadiation = "shortwave_radiation"
        case isDay = "is_day"
    }

    init(
        time: [Int] = [],
        temperature: [Double?] = [],
        apparentTemperature: [Double?] = [],
        precipitationProbability: [Int?] = [],
        weatherCode: [Int?] = [],
        windSpeed: [Double?] = [],
        windDirection: [Int?] = [],
        relativeHumidity: [Int?] = [],
        seaLevelPressure: [Double?] = [],
        uvIndex: [Double?] = [],
        shortwaveRadiation: [Double?] = [],
        isDay: [Int?] = []
    ) {
        self.time = time
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.precipitationProbability = precipitationProbability
        self.weatherCode = weatherCode
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.relativeHumidity = relativeHumidity
        self.seaLevelPressure = seaLevelPressure
        self.uvIndex = uvIndex
        self.shortwaveRadiation = shortwaveRadiation
        self.isDay = isDay
    }

    /// Missing arrays decode as empty, matching Open-Meteo omitting fields it has no data for.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = try c.decodeIfPresent([Int].self, forKey: .time) ?? []
        temperature = try c.decodeIfPresent([Double?].self, forKey: .temperature) ?? []
        apparentTemperature = try c.decodeIfPresent([Double?].self, forKey: .apparentTemperature) ?? []
        precipitationProbability = try c.decodeIfPresent([Int?].self, forKey: .precipitationProbability) ?? []
        weatherCode = try c.decodeIfPresent([Int?].self, forKey: .weatherCode) ?? []
        windSpeed = try c.decodeIfPresent([Double?].self, forKey: .windSpeed) ?? []
        windDirection = try c.decodeIfPresent([Int?].self, forKey: .windDirection) ?? []
        relativeHumidity = try c.decodeIfPresent([Int?].self, forKey: .relativeHumidity) ?? []
        seaLevelPressure = try c.decodeIfPresent([Double?].self, forKey: .seaLevelPressure) ?? []
        uvIndex = try c.decodeIfPresent([Double?].self, forKey: .uvIndex) ?? []
        shortwaveRadiation = try c.decodeIfPresent([Double?].self, forKey: .shortwaveRadiation) ?? []
        isDay = try c.decodeIfPresent([Int?].self, forKey: .isDay) ?? []
    }
}

extension Array {
    subscript(ifPresent index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
