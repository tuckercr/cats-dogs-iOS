import FirebaseAnalytics
import Foundation

/// Same events and parameter names as Android's `AnalyticsRepository`, so both platforms report into
/// one set of Firebase dashboards. Does nothing when Firebase isn't configured.
@MainActor
final class AnalyticsRepository {
    static let shared = AnalyticsRepository()

    nonisolated static let eventOnboardingComplete = "onboarding_complete"
    nonisolated static let eventCityAdded = "city_added"
    nonisolated static let eventSettingsOpened = "settings_opened"
    nonisolated static let eventWeatherError = "weather_error"
    nonisolated static let paramErrorKey = "error_key"

    private init() {}

    func logOnboardingComplete() { log(Self.eventOnboardingComplete) }

    func logCityAdded() { log(Self.eventCityAdded) }

    func logSettingsOpened() { log(Self.eventSettingsOpened) }

    func logWeatherError(_ errorKey: String) {
        log(Self.eventWeatherError, parameters: [Self.paramErrorKey: errorKey])
    }

    private func log(_ event: String, parameters: [String: Any]? = nil) {
        guard FirebaseSetup.isConfigured else { return }
        Analytics.logEvent(event, parameters: parameters)
    }
}
