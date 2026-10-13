import Foundation
import Observation

/// Holds the RainViewer radar timeline. The frame list is global (not per city), so one shared
/// instance holds it. `load()` fetches it the first time and again once it's stale, so an app that
/// sat in the background for hours doesn't replay old frames labelled "Now".
@MainActor
@Observable
final class RadarViewModel {
    static let shared = RadarViewModel()

    /// Delay between animation frames, from Remote Config (default 850 ms).
    let frameInterval: Duration

    /// RainViewer publishes a new frame every 10 minutes, and keeps only about two hours of them.
    nonisolated static let staleAfter: TimeInterval = 10 * 60
    /// How often the radar card checks for staleness while it's on screen.
    nonisolated static let recheckInterval: Duration = .seconds(60)

    private(set) var timeline: LoadingState<RadarTimeline> = .idle

    private let fetchTimeline: @Sendable () async throws -> RadarTimeline
    private let now: () -> Date
    private var loadedAt: Date?
    private var isRefreshing = false

    init(
        frameInterval: Duration? = nil,
        fetchTimeline: (@Sendable () async throws -> RadarTimeline)? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.frameInterval = frameInterval ?? RemoteConfigRepository.shared.radarFrameInterval
        self.fetchTimeline = fetchTimeline ?? { try await RadarRepository().timeline() }
        self.now = now
    }

    /// Fetches the timeline the first time, and refreshes it once it's stale. Safe to call often:
    /// it does nothing while a fetch is in flight or the timeline is fresh.
    func load() {
        switch timeline {
        case .loading:
            return
        case .success:
            guard !isRefreshing, let loadedAt, now().timeIntervalSince(loadedAt) >= Self.staleAfter else { return }
            refresh()
            return
        case .idle, .error:
            break
        }
        timeline = .loading
        Task {
            do {
                timeline = .success(try await fetchTimeline())
                loadedAt = now()
            } catch {
                timeline = .error(errorKey: "radar_unavailable", canRetry: true)
            }
        }
    }

    /// Keeps the old frames on screen until the new ones arrive. A failed refresh keeps them too;
    /// the next resume or recheck tries again.
    private func refresh() {
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            guard let fresh = try? await fetchTimeline() else { return }
            timeline = .success(fresh)
            loadedAt = now()
        }
    }

    func retry() {
        timeline = .idle
        load()
    }
}
