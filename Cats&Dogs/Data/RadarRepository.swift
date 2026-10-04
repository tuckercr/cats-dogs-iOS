import Foundation

enum RadarError: Error, Equatable {
    case network
    case http(statusCode: Int)
    case empty
}

/// Fetches the RainViewer radar animation timeline (observed past frames + short-range nowcast).
/// The frame list is global, only the tiles are location-specific, so callers fetch it once and
/// reuse it across cities.
struct RadarRepository: Sendable {
    private static let weatherMapsURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func timeline() async throws -> RadarTimeline {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: Self.weatherMapsURL)
        } catch {
            throw RadarError.network
        }
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw RadarError.http(statusCode: http.statusCode)
        }
        return try Self.parseTimeline(data)
    }

    /// Parses the weather-maps payload into an ordered timeline: past frames (chronological)
    /// followed by nowcast frames.
    static func parseTimeline(_ data: Data) throws -> RadarTimeline {
        guard let dto = try? JSONDecoder().decode(RainViewerMapsDTO.self, from: data) else {
            throw RadarError.empty
        }
        let past = dto.radar.past.map { RadarFrame(timeEpochSeconds: $0.time, path: $0.path, isForecast: false) }
        let nowcast = dto.radar.nowcast.map { RadarFrame(timeEpochSeconds: $0.time, path: $0.path, isForecast: true) }
        let frames = (past + nowcast).sorted { $0.timeEpochSeconds < $1.timeEpochSeconds }
        guard !dto.host.trimmingCharacters(in: .whitespaces).isEmpty, !frames.isEmpty else {
            throw RadarError.empty
        }
        return RadarTimeline(host: dto.host, frames: frames)
    }
}

/// Response of RainViewer's public `weather-maps.json` endpoint.
private struct RainViewerMapsDTO: Decodable {
    var host = ""
    var radar = RainViewerRadarDTO()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        radar = try c.decodeIfPresent(RainViewerRadarDTO.self, forKey: .radar) ?? RainViewerRadarDTO()
    }

    enum CodingKeys: String, CodingKey { case host, radar }
}

private struct RainViewerRadarDTO: Decodable {
    var past: [RainViewerFrameDTO] = []
    var nowcast: [RainViewerFrameDTO] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        past = try c.decodeIfPresent([RainViewerFrameDTO].self, forKey: .past) ?? []
        nowcast = try c.decodeIfPresent([RainViewerFrameDTO].self, forKey: .nowcast) ?? []
    }

    enum CodingKeys: String, CodingKey { case past, nowcast }
}

private struct RainViewerFrameDTO: Decodable {
    let time: Int
    let path: String
}
