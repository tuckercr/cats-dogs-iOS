import Foundation

/// Turns an Open-Meteo response into day forecasts: true hourly data in the city's own time zone,
/// with UV index and an estimated pavement temperature. Coordinates only; name-only cities fall
/// back to OpenWeatherMap in `WeatherRepository`.
enum OpenMeteoForecast {
    /// Converts the parallel hourly arrays into day forecasts, dropping hours before the current
    /// one so hourly views start at "now".
    static func dayForecasts(
        from response: OpenMeteoResponse,
        units: WeatherUnits,
        now: Date
    ) -> [DayForecast] {
        let hourly = response.hourly
        let timeZone = response.timezone.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(secondsFromGMT: response.utcOffsetSeconds)
            ?? .current
        let currentHourStart = startOfLocalHour(containing: now, in: timeZone)

        let slots = hourly.time.indices.compactMap { i -> ForecastAggregator.Slot? in
            let epoch = hourly.time[i]
            guard let temperature = hourly.temperature[ifPresent: i] ?? nil, epoch >= currentHourStart else {
                return nil
            }
            let isDay = (hourly.isDay[ifPresent: i] ?? nil) == 1
            let condition = WmoWeatherCodes.condition((hourly.weatherCode[ifPresent: i] ?? nil) ?? 3, isDay: isDay)
            return ForecastAggregator.Slot(
                epochSeconds: epoch,
                temperature: temperature,
                feelsLike: (hourly.apparentTemperature[ifPresent: i] ?? nil) ?? temperature,
                conditionMain: condition.main,
                description: condition.description,
                iconCode: condition.iconCode,
                windSpeed: (hourly.windSpeed[ifPresent: i] ?? nil) ?? 0,
                windDeg: (hourly.windDirection[ifPresent: i] ?? nil) ?? 0,
                humidity: (hourly.relativeHumidity[ifPresent: i] ?? nil) ?? 0,
                pressure: Int((hourly.seaLevelPressure[ifPresent: i] ?? nil) ?? 0),
                pop: Double((hourly.precipitationProbability[ifPresent: i] ?? nil) ?? 0) / 100,
                uvIndex: hourly.uvIndex[ifPresent: i] ?? nil,
                pavementTemperature: units.fromCelsius(
                    PavementHeat.estimateC(
                        airC: units.toCelsius(temperature),
                        shortwaveRadiationWm2: hourly.shortwaveRadiation[ifPresent: i] ?? nil,
                        isDay: isDay
                    )
                )
            )
        }
        return ForecastAggregator.aggregate(slots: slots, timeZone: timeZone, units: units)
    }

    /// Slots start on local hour boundaries, which aren't UTC hour boundaries in half-hour zones
    /// (India +5:30, Adelaide +9:30, Nepal +5:45), so "now" is floored in local time.
    private static func startOfLocalHour(containing date: Date, in timeZone: TimeZone) -> Int {
        let now = Int(date.timeIntervalSince1970)
        let offset = timeZone.secondsFromGMT(for: date)
        let localNow = now + offset
        let intoHour = ((localNow % 3600) + 3600) % 3600
        return localNow - intoHour - offset
    }
}
