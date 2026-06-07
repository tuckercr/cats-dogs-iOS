import Foundation

struct GeocodingClient {
    private let session: URLSession
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openweathermap.org/")!

    init(session: URLSession = .shared, apiKey: String = AppConfig.openWeatherApiKey) {
        self.session = session
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func directSearch(query: String, limit: Int = 8) async throws -> [GeocodingDirectDTO] {
        guard !apiKey.isEmpty else { throw OpenWeatherClientError.missingApiKey }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("geo/1.0/direct"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "appid", value: apiKey),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw OpenWeatherClientError.invalidPayload
        }
        return try JSONDecoder().decode([GeocodingDirectDTO].self, from: data)
    }
}
