import CoreLocation
import Foundation
import Observation
import UserNotifications

/// iOS only lists a permission in the Settings app once the app has asked for it, so a permission
/// that was never requested has to be requested in-app; only a denied one can be fixed in Settings.
enum PermissionStatus: Equatable {
    case granted
    case notDetermined
    case denied

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: self = .granted
        case .notDetermined: self = .notDetermined
        default: self = .denied
        }
    }

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .granted
        case .notDetermined: self = .notDetermined
        default: self = .denied
        }
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var unitOverride: UnitOverride
    private(set) var locationPermission: PermissionStatus = .notDetermined
    private(set) var notificationPermission: PermissionStatus = .notDetermined

    private let preferences: PreferencesStore
    private let locationStatus: () -> CLAuthorizationStatus
    private let notificationStatus: () async -> UNAuthorizationStatus
    private let requestNotificationAuthorization: () async -> Bool
    private let rescheduleNotifications: () async -> Void

    init(
        preferences: PreferencesStore? = nil,
        locationStatus: (() -> CLAuthorizationStatus)? = nil,
        notificationStatus: (() async -> UNAuthorizationStatus)? = nil,
        requestNotificationAuthorization: (() async -> Bool)? = nil,
        rescheduleNotifications: (() async -> Void)? = nil
    ) {
        let preferences = preferences ?? .shared
        self.preferences = preferences
        self.locationStatus = locationStatus ?? { CLLocationManager().authorizationStatus }
        self.notificationStatus = notificationStatus ?? {
            await WeatherNotificationScheduler.shared.authorizationStatus()
        }
        self.requestNotificationAuthorization = requestNotificationAuthorization ?? {
            await WeatherNotificationScheduler.shared.requestAuthorization()
        }
        self.rescheduleNotifications = rescheduleNotifications ?? {
            await WeatherNotificationScheduler.shared.scheduleDailyNotifications()
        }
        unitOverride = preferences.unitOverride
    }

    func setUnitOverride(_ override: UnitOverride) {
        unitOverride = override
        preferences.setUnitOverride(override)
    }

    func clearCache() {
        preferences.clearCache()
    }

    func refreshPermissions() async {
        locationPermission = PermissionStatus(locationStatus())
        notificationPermission = PermissionStatus(await notificationStatus())
    }

    /// Shows the system prompt. Only meaningful while the status is `.notDetermined`.
    func requestNotificationPermission() async {
        if await requestNotificationAuthorization() {
            await rescheduleNotifications()
        }
        await refreshPermissions()
    }
}
