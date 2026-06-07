import Foundation

struct WeatherRepository {
    private let client: any OpenWeatherAPI
    private let timeZone: TimeZone

    init(client: any OpenWeatherAPI = OpenWeatherClient(), timeZone: TimeZone = .current) {
        self.client = client
        self.timeZone = timeZone
    }

    func fetchCurrentWeather(
        units: WeatherUnits,
        locationLabel: String = "",
        cityQuery: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Result<CurrentWeather, Error> {
        if let latitude, let longitude {
            return await performCurrentFetch(
                units: units,
                locationLabel: locationLabel,
                cityQuery: nil,
                latitude: latitude,
                longitude: longitude
            )
        }

        let query = cityQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            return .failure(OpenWeatherClientError.emptyQuery)
        }

        return await performCurrentFetch(
            units: units,
            locationLabel: locationLabel,
            cityQuery: query,
            latitude: nil,
            longitude: nil
        )
    }

    func fetchForecast(
        units: WeatherUnits,
        cityQuery: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Result<[DayForecast], Error> {
        if let latitude, let longitude {
            return await performForecastFetch(
                units: units,
                cityQuery: nil,
                latitude: latitude,
                longitude: longitude
            )
        }

        let query = cityQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            return .failure(OpenWeatherClientError.emptyQuery)
        }

        return await performForecastFetch(
            units: units,
            cityQuery: query,
            latitude: nil,
            longitude: nil
        )
    }

    private func performCurrentFetch(
        units: WeatherUnits,
        locationLabel: String,
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?
    ) async -> Result<CurrentWeather, Error> {
        do {
            let response = try await client.currentWeather(
                cityQuery: cityQuery,
                latitude: latitude,
                longitude: longitude,
                units: units
            )
            return .success(try mapCurrent(response, units: units, locationLabel: locationLabel))
        } catch {
            return .failure(error)
        }
    }

    private func performForecastFetch(
        units: WeatherUnits,
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?
    ) async -> Result<[DayForecast], Error> {
        do {
            let response = try await client.forecast(
                cityQuery: cityQuery,
                latitude: latitude,
                longitude: longitude,
                units: units
            )
            return .success(try mapForecast(response, units: units))
        } catch {
            return .failure(error)
        }
    }

    private func mapCurrent(
        _ response: CurrentWeatherResponse,
        units: WeatherUnits,
        locationLabel: String
    ) throws -> CurrentWeather {
        guard let weather = response.weather.first else {
            throw OpenWeatherClientError.invalidPayload
        }
        let displayCity = locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? response.name

        return CurrentWeather(
            cityName: displayCity,
            conditionMain: weather.main,
            description: weather.description.weatherSentenceCased,
            iconCode: weather.icon,
            temperature: response.main.temp,
            feelsLike: response.main.feelsLike,
            humidityPercent: response.main.humidity,
            windSpeed: response.wind.speed,
            units: units
        )
    }

    private func mapForecast(_ response: ForecastResponse, units: WeatherUnits) throws -> [DayForecast] {
        var slots: [ForecastAggregator.Slot] = []
        for item in response.list {
            guard let weather = item.weather.first else {
                throw OpenWeatherClientError.invalidPayload
            }
            slots.append(
                ForecastAggregator.Slot(
                    epochSeconds: item.dt,
                    temperature: item.main.temp,
                    feelsLike: item.main.feelsLike,
                    conditionMain: weather.main,
                    description: weather.description,
                    iconCode: weather.icon
                )
            )
        }
        return ForecastAggregator.aggregate(slots: slots, timeZone: timeZone, units: units)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
