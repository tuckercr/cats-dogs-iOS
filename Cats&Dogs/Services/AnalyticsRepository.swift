import FirebaseAnalytics
import Foundation

/// Same events and parameter names as Android's `AnalyticsRepository`, so both platforms report into
/// one set of Firebase dashboards.
///
/// An event is only sent when all three gates are open, as on Android:
/// 1. Firebase is configured (`GoogleService-Info.plist` is bundled).
/// 2. The Remote Config kill switch `analytics_enabled` is on.
/// 3. The user hasn't turned off "Share usage statistics". That one is also enforced in the SDK, so
///    Firebase's automatic events (sessions, screen views) stop too.
@MainActor
final class AnalyticsRepository {
    static let shared = AnalyticsRepository()

    nonisolated static let eventOnboardingComplete = "onboarding_complete"
    nonisolated static let eventCityAdded = "city_added"
    nonisolated static let eventSettingsOpened = "settings_opened"
    nonisolated static let eventWeatherError = "weather_error"
    nonisolated static let paramErrorKey = "error_key"

    private let preferences: PreferencesStore
    private let isConfigured: () -> Bool
    private let remotelyEnabled: () -> Bool
    private let sendEvent: (_ name: String, _ parameters: [String: Any]?) -> Void
    private let setCollectionEnabled: (Bool) -> Void

    init(
        preferences: PreferencesStore? = nil,
        isConfigured: @escaping () -> Bool = { FirebaseSetup.isConfigured },
        remotelyEnabled: @escaping () -> Bool = { RemoteConfigRepository.shared.analyticsEnabled },
        sendEvent: @escaping (_ name: String, _ parameters: [String: Any]?) -> Void = {
            Analytics.logEvent($0, parameters: $1)
        },
        setCollectionEnabled: @escaping (Bool) -> Void = { Analytics.setAnalyticsCollectionEnabled($0) }
    ) {
        self.preferences = preferences ?? .shared
        self.isConfigured = isConfigured
        self.remotelyEnabled = remotelyEnabled
        self.sendEvent = sendEvent
        self.setCollectionEnabled = setCollectionEnabled
    }

    func logOnboardingComplete() { log(Self.eventOnboardingComplete) }

    func logCityAdded() { log(Self.eventCityAdded) }

    func logSettingsOpened() { log(Self.eventSettingsOpened) }

    func logWeatherError(_ errorKey: String) {
        log(Self.eventWeatherError, parameters: [Self.paramErrorKey: errorKey])
    }

    /// Pushes the user's choice into the SDK. Run at launch and whenever the setting changes.
    func applyUsageSharingPreference() {
        guard isConfigured() else { return }
        setCollectionEnabled(preferences.shareUsageStatistics)
    }

    private func log(_ event: String, parameters: [String: Any]? = nil) {
        guard isConfigured(), remotelyEnabled(), preferences.shareUsageStatistics else { return }
        sendEvent(event, parameters)
    }
}
