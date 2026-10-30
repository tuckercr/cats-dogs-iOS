import Foundation

protocol AirQualityAPI: Sendable {
    func current(latitude: Double, longitude: Double) async throws -> AirQualityResponse
    func hourly(latitude: Double, longitude: Double) async throws -> AirQualityHourlyResponse
}

/// Open-Meteo's air quality endpoint: free, keyless and worldwide. Errors reuse
/// `OpenWeatherClientError`, like `OpenMeteoClient`.
struct AirQualityClient: AirQualityAPI {
    private let session: URLSession
    private static let baseURL = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func current(latitude: Double, longitude: Double) async throws -> AirQualityResponse {
        try await get(latitude: latitude, longitude: longitude, [
            URLQueryItem(
                name: "current",
                value: AirQualityResponse.Current.CodingKeys.allCases.map(\.rawValue).joined(separator: ",")
            ),
        ])
    }

    /// The next two days hour by hour, enough for the walk planner's day ahead.
    func hourly(latitude: Double, longitude: Double) async throws -> AirQualityHourlyResponse {
        try await get(latitude: latitude, longitude: longitude, [
            URLQueryItem(name: "hourly", value: "us_aqi,european_aqi"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ])
    }

    private func get<Response: Decodable>(
        latitude: Double,
        longitude: Double,
        _ fields: [URLQueryItem]
    ) async throws -> Response {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            // The response's time zone picks the scale (European or US).
            URLQueryItem(name: "timezone", value: "auto"),
        ] + fields

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
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw OpenWeatherClientError.invalidPayload
        }
    }
}
