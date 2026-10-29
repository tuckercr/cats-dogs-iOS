import Observation
import UserNotifications

/// iOS Settings shows a link to the app's own notification settings on its notification page (asked
/// for with `.providesAppNotificationSettings`). Tapping it opens the app with this set, and RootView
/// goes to the Notifications screen.
@MainActor
@Observable
final class NotificationSettingsLink: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationSettingsLink()

    var isRequested = false

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        Task { @MainActor in self.isRequested = true }
    }

    #if DEBUG
    /// Debug builds only: show them with the app open too, for the samples. Release builds keep
    /// the system default, which doesn't.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
    #endif
}
