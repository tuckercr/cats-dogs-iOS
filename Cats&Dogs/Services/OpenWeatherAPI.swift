import Foundation

protocol OpenWeatherAPI: Sendable {
    func currentWeather(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> CurrentWeatherResponse

    func forecast(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> ForecastResponse
}

extension OpenWeatherClient: OpenWeatherAPI {}
