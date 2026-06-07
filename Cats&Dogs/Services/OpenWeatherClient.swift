import Foundation

enum OpenWeatherClientError: Error, Equatable {
    case missingApiKey
    case emptyQuery
    case network
    case http(statusCode: Int, message: String)
    case invalidPayload
}

struct OpenWeatherClient {
    private let session: URLSession
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openweathermap.org/")!

    init(session: URLSession = .shared, apiKey: String = AppConfig.openWeatherApiKey) {
        self.session = session
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func currentWeather(
        cityQuery: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        units: WeatherUnits
    ) async throws -> CurrentWeatherResponse {
        try validateApiKey()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("data/2.5/weather"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems(
            cityQuery: cityQuery,
            latitude: latitude,
            longitude: longitude,
            units: units
        )
        return try await request(url: components.url!)
    }

    func forecast(
        cityQuery: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        units: WeatherUnits
    ) async throws -> ForecastResponse {
        try validateApiKey()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("data/2.5/forecast"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems(
            cityQuery: cityQuery,
            latitude: latitude,
            longitude: longitude,
            units: units
        )
        return try await request(url: components.url!)
    }

    private func validateApiKey() throws {
        guard !apiKey.isEmpty else { throw OpenWeatherClientError.missingApiKey }
    }

    private func queryItems(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: units.apiValue),
        ]
        if let latitude, let longitude {
            items.append(URLQueryItem(name: "lat", value: String(latitude)))
            items.append(URLQueryItem(name: "lon", value: String(longitude)))
        } else if let cityQuery, !cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "q", value: cityQuery))
        }
        return items
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw OpenWeatherClientError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenWeatherClientError.invalidPayload
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(OpenWeatherErrorResponse.self, from: data).message)
                ?? "http_\(http.statusCode)"
            throw OpenWeatherClientError.http(statusCode: http.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenWeatherClientError.invalidPayload
        }
    }
}
