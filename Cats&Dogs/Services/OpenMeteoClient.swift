import Foundation

protocol OpenMeteoAPI: Sendable {
    func forecast(latitude: Double, longitude: Double, units: WeatherUnits) async throws -> OpenMeteoResponse
}

/// Open-Meteo's forecast endpoint: free and keyless. Errors reuse `OpenWeatherClientError` so they
/// map onto the same user-facing messages as the OpenWeatherMap calls.
struct OpenMeteoClient: OpenMeteoAPI {
    private let session: URLSession
    private static let baseURL = URL(string: "https://api.open-meteo.com/v1/forecast")!
    private static let forecastDays = 7
    private static let hourlyFields = [
        "temperature_2m", "apparent_temperature", "precipitation_probability", "weather_code",
        "wind_speed_10m", "wind_direction_10m", "relative_humidity_2m", "pressure_msl",
        "uv_index", "shortwave_radiation", "is_day",
    ].joined(separator: ",")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func forecast(latitude: Double, longitude: Double, units: WeatherUnits) async throws -> OpenMeteoResponse {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: Self.hourlyFields),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: String(Self.forecastDays)),
            URLQueryItem(name: "temperature_unit", value: units == .imperial ? "fahrenheit" : "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: units == .imperial ? "mph" : "ms"),
        ]

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: components.url!)
        } catch {
            throw OpenWeatherClientError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw OpenWeatherClientError.invalidPayload
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw OpenWeatherClientError.http(statusCode: http.statusCode, message: "http_\(http.statusCode)")
        }
        do {
            return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw OpenWeatherClientError.invalidPayload
        }
    }
}
