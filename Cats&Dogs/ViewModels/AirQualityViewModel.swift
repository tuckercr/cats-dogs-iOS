import Foundation
import Observation

/// The air quality for the city on screen. Kept in memory per city and fetched again once it's an
/// hour old, which is how often Open-Meteo updates it. Nothing shows until a reading arrives, and a
/// failed fetch just leaves the tile out. It's Open-Meteo data, so Remote Config's
/// `open_meteo_enabled` switches it off too.
@MainActor
@Observable
final class AirQualityViewModel {
    nonisolated static let staleAfter: TimeInterval = 60 * 60

    private(set) var readings: [String: AirQuality] = [:]

    private let fetch: @Sendable (Double, Double) async throws -> AirQualityResponse
    private let now: () -> Date
    private let isEnabled: () -> Bool
    private var fetchedAt: [String: Date] = [:]
    private var inFlight: Set<String> = []

    init(
        fetch: (@Sendable (Double, Double) async throws -> AirQualityResponse)? = nil,
        now: (() -> Date)? = nil,
        isEnabled: (() -> Bool)? = nil
    ) {
        self.fetch = fetch ?? { try await AirQualityClient().current(latitude: $0, longitude: $1) }
        self.now = now ?? { Date() }
        self.isEnabled = isEnabled ?? { RemoteConfigRepository.openMeteoEnabled }
    }

    func reading(for location: SavedLocation?) -> AirQuality? {
        location.flatMap { readings[$0.cacheKey] }
    }

    /// Fetches the city's reading unless a fresh one is held or a fetch is in flight. Cities without
    /// coordinates wait until they're geocoded.
    func load(for location: SavedLocation?) {
        guard isEnabled(), let location, let latitude = location.latitude, let longitude = location.longitude else { return }
        let key = location.cacheKey
        if let fetchedAt = fetchedAt[key], now().timeIntervalSince(fetchedAt) < Self.staleAfter { return }
        guard inFlight.insert(key).inserted else { return }
        Task {
            defer { inFlight.remove(key) }
            guard let response = try? await fetch(latitude, longitude),
                  let reading = AirQuality.from(response) else { return }
            readings[key] = reading
            fetchedAt[key] = now()
        }
    }
}
