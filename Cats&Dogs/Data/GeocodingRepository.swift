import Foundation

struct GeocodingRepository {
    private let client: any GeocodingAPI

    init(client: any GeocodingAPI = GeocodingClient()) {
        self.client = client
    }

    func searchCities(query: String) async -> Result<[CitySuggestion], Error> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return .success([]) }

        do {
            let results = try await client.directSearch(query: trimmed, limit: 8)
            return .success(results.map(mapSuggestion))
        } catch {
            return .failure(error)
        }
    }

    private func mapSuggestion(_ dto: GeocodingDirectDTO) -> CitySuggestion {
        let labelParts = [dto.name, dto.state?.nilIfEmpty, dto.country].compactMap { $0 }
        return CitySuggestion(
            label: labelParts.joined(separator: ", "),
            weatherLat: dto.lat,
            weatherLon: dto.lon
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
