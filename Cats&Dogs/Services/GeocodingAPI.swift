import Foundation

protocol GeocodingAPI: Sendable {
    func directSearch(query: String, limit: Int) async throws -> [GeocodingDirectDTO]
}

extension GeocodingClient: GeocodingAPI {}
