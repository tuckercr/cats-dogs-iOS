import Foundation
import Observation

/// Holds the RainViewer radar timeline. The frame list is global (not per city), so one shared
/// instance fetches it once; `load()` is a no-op while a load is in flight or after it succeeded.
@MainActor
@Observable
final class RadarViewModel {
    static let shared = RadarViewModel()

    /// Delay between animation frames. Android reads this from Remote Config (default 850 ms).
    nonisolated static let frameInterval: Duration = .milliseconds(850)

    private(set) var timeline: LoadingState<RadarTimeline> = .idle

    private let fetchTimeline: @Sendable () async throws -> RadarTimeline

    init(fetchTimeline: (@Sendable () async throws -> RadarTimeline)? = nil) {
        self.fetchTimeline = fetchTimeline ?? { try await RadarRepository().timeline() }
    }

    func load() {
        switch timeline {
        case .loading, .success: return
        case .idle, .error: break
        }
        timeline = .loading
        Task {
            do {
                timeline = .success(try await fetchTimeline())
            } catch {
                timeline = .error(errorKey: "radar_unavailable", canRetry: true)
            }
        }
    }

    func retry() {
        timeline = .idle
        load()
    }
}
