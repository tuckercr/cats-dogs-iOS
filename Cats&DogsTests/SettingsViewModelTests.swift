import CoreLocation
import UserNotifications
import XCTest
@testable import Cats_Dogs

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var preferences: IsolatedPreferences!

    override func setUp() async throws {
        preferences = IsolatedPreferences()
    }

    override func tearDown() async throws {
        preferences.destroy()
    }

    func testUnitOverrideDefaultsToSystem() {
        XCTAssertEqual(SettingsViewModel(preferences: preferences.store).unitOverride, .system)
    }

    func testUnitOverrideReflectsStoredValue() {
        preferences.store.setUnitOverride(.imperial)

        XCTAssertEqual(SettingsViewModel(preferences: preferences.store).unitOverride, .imperial)
    }

    func testSetUnitOverrideUpdatesStateAndPersists() {
        let viewModel = SettingsViewModel(preferences: preferences.store)

        viewModel.setUnitOverride(.metric)

        XCTAssertEqual(viewModel.unitOverride, .metric)
        XCTAssertEqual(preferences.reopened().unitOverride, .metric)
    }

    func testClearCacheRemovesCachedWeatherAndForecast() async {
        preferences.store.setCachedWeather(await makeCurrentWeather(), for: "austin")
        preferences.store.setCachedForecast(await makeForecast(), for: "austin")
        XCTAssertNotNil(preferences.store.cachedWeather(for: "austin"))

        SettingsViewModel(preferences: preferences.store).clearCache()

        XCTAssertNil(preferences.store.cachedWeather(for: "austin"))
        XCTAssertNil(preferences.store.cachedForecast(for: "austin"))
    }

    func testClearCacheKeepsSavedLocationsAndUnitOverride() {
        let austin = SavedLocation(label: "Austin", latitude: 30.27, longitude: -97.74)
        preferences.store.setSavedLocations([austin])
        preferences.store.setUnitOverride(.imperial)

        SettingsViewModel(preferences: preferences.store).clearCache()

        XCTAssertEqual(preferences.store.savedLocations, [austin])
        XCTAssertEqual(preferences.store.unitOverride, .imperial)
    }

    // MARK: - Permissions

    func testPermissionStatusMapping() {
        XCTAssertEqual(PermissionStatus(CLAuthorizationStatus.authorizedWhenInUse), .granted)
        XCTAssertEqual(PermissionStatus(CLAuthorizationStatus.authorizedAlways), .granted)
        XCTAssertEqual(PermissionStatus(CLAuthorizationStatus.notDetermined), .notDetermined)
        XCTAssertEqual(PermissionStatus(CLAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus(CLAuthorizationStatus.restricted), .denied)

        XCTAssertEqual(PermissionStatus(UNAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus(UNAuthorizationStatus.provisional), .granted)
        XCTAssertEqual(PermissionStatus(UNAuthorizationStatus.notDetermined), .notDetermined)
        XCTAssertEqual(PermissionStatus(UNAuthorizationStatus.denied), .denied)
    }

    func testRefreshPermissionsReflectsSystemStatus() async {
        let viewModel = makeViewModel(location: .denied, notifications: { .notDetermined })

        await viewModel.refreshPermissions()

        XCTAssertEqual(viewModel.locationPermission, .denied)
        XCTAssertEqual(viewModel.notificationPermission, .notDetermined)
    }

    /// Regression: "Not now" during onboarding leaves the status undetermined, and iOS Settings has no
    /// Notifications entry for the app until it has asked — so the prompt must be reachable in-app.
    func testRequestingNotificationsWhenGrantedUpdatesStatusAndSchedulesNotifications() async {
        var systemStatus = UNAuthorizationStatus.notDetermined
        var prompts = 0
        var reschedules = 0
        let viewModel = makeViewModel(
            notifications: { systemStatus },
            onRequest: {
                prompts += 1
                systemStatus = .authorized
                return true
            },
            onReschedule: { reschedules += 1 }
        )
        await viewModel.refreshPermissions()
        XCTAssertEqual(viewModel.notificationPermission, .notDetermined)

        await viewModel.requestNotificationPermission()

        XCTAssertEqual(prompts, 1)
        XCTAssertEqual(reschedules, 1)
        XCTAssertEqual(viewModel.notificationPermission, .granted)
    }

    func testDecliningTheNotificationPromptMarksDeniedAndSchedulesNothing() async {
        var systemStatus = UNAuthorizationStatus.notDetermined
        var reschedules = 0
        let viewModel = makeViewModel(
            notifications: { systemStatus },
            onRequest: {
                systemStatus = .denied
                return false
            },
            onReschedule: { reschedules += 1 }
        )

        await viewModel.requestNotificationPermission()

        XCTAssertEqual(reschedules, 0)
        XCTAssertEqual(viewModel.notificationPermission, .denied)
    }

    private func makeViewModel(
        location: CLAuthorizationStatus = .notDetermined,
        notifications: @escaping () -> UNAuthorizationStatus = { .notDetermined },
        onRequest: @escaping () -> Bool = { false },
        onReschedule: @escaping () -> Void = {}
    ) -> SettingsViewModel {
        SettingsViewModel(
            preferences: preferences.store,
            locationStatus: { location },
            notificationStatus: { notifications() },
            requestNotificationAuthorization: { onRequest() },
            rescheduleNotifications: { onReschedule() }
        )
    }
}
