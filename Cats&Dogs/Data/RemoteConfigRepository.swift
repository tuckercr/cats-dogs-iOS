import FirebaseRemoteConfig
import Foundation

/// Server-tunable values, with the same keys, defaults and limits as Android's
/// `RemoteConfigRepository`. Falls back to the defaults when Firebase isn't configured.
@MainActor
final class RemoteConfigRepository {
    static let shared = RemoteConfigRepository()

    nonisolated static let keyRefreshInterval = "weather_refresh_interval_minutes"
    nonisolated static let defaultRefreshIntervalMinutes = 30
    /// Matches Android's WorkManager floor. iOS treats the interval as a minimum anyway.
    nonisolated static let minRefreshIntervalMinutes = 15

    nonisolated static let keyRadarFrameInterval = "radar_frame_interval_ms"
    nonisolated static let defaultRadarFrameIntervalMs = 850
    nonisolated static let radarFrameIntervalRangeMs = 100 ... 5000

    private let remoteConfig: RemoteConfig?

    private init() {
        guard FirebaseSetup.isConfigured else {
            remoteConfig = nil
            return
        }
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // Fetch new values at most every hour, as on Android.
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            Self.keyRefreshInterval: NSNumber(value: Self.defaultRefreshIntervalMinutes),
            Self.keyRadarFrameInterval: NSNumber(value: Self.defaultRadarFrameIntervalMs),
        ])
        // Activated values apply from the next read; this launch keeps what was last activated.
        remoteConfig.fetchAndActivate()
        self.remoteConfig = remoteConfig
    }

    var refreshInterval: TimeInterval {
        let minutes = remoteConfig?[Self.keyRefreshInterval].numberValue.intValue
        return Self.refreshInterval(minutes: minutes)
    }

    var radarFrameInterval: Duration {
        let milliseconds = remoteConfig?[Self.keyRadarFrameInterval].numberValue.intValue
        return Self.radarFrameInterval(milliseconds: milliseconds)
    }

    nonisolated static func refreshInterval(minutes: Int?) -> TimeInterval {
        TimeInterval(max(minutes ?? defaultRefreshIntervalMinutes, minRefreshIntervalMinutes) * 60)
    }

    /// Out-of-range values fall back to the default rather than the nearest limit, as on Android.
    nonisolated static func radarFrameInterval(milliseconds: Int?) -> Duration {
        guard let milliseconds, radarFrameIntervalRangeMs.contains(milliseconds) else {
            return .milliseconds(defaultRadarFrameIntervalMs)
        }
        return .milliseconds(milliseconds)
    }
}
