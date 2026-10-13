import XCTest
@testable import Cats_Dogs

@MainActor
final class AnalyticsRepositoryTests: XCTestCase {
    private var preferences: IsolatedPreferences!
    private var sent: [(name: String, parameters: [String: Any]?)] = []
    private var collectionSettings: [Bool] = []

    override func setUp() async throws {
        preferences = IsolatedPreferences()
        sent = []
        collectionSettings = []
    }

    override func tearDown() async throws {
        preferences.destroy()
    }

    func testSendsEventsWhenEveryGateIsOpen() {
        let analytics = makeRepository()

        analytics.logOnboardingComplete()
        analytics.logCityAdded()
        analytics.logSettingsOpened()
        analytics.logWeatherError("offline")

        XCTAssertEqual(sent.map(\.name), ["onboarding_complete", "city_added", "settings_opened", "weather_error"])
        XCTAssertEqual(sent.last?.parameters?["error_key"] as? String, "offline")
    }

    func testDropsEventsWithoutFirebase() {
        makeRepository(configured: false).logCityAdded()

        XCTAssertTrue(sent.isEmpty)
    }

    func testRemoteKillSwitchDropsEvents() {
        makeRepository(remotelyEnabled: false).logCityAdded()

        XCTAssertTrue(sent.isEmpty)
    }

    func testUserOptOutDropsEvents() {
        preferences.store.setShareUsageStatistics(false)

        makeRepository().logCityAdded()

        XCTAssertTrue(sent.isEmpty)
    }

    func testUsageSharingPreferenceIsPushedToTheSdk() {
        let analytics = makeRepository()

        analytics.applyUsageSharingPreference()
        preferences.store.setShareUsageStatistics(false)
        analytics.applyUsageSharingPreference()

        XCTAssertEqual(collectionSettings, [true, false])
    }

    func testUsageSharingPreferenceIsNotPushedWithoutFirebase() {
        makeRepository(configured: false).applyUsageSharingPreference()

        XCTAssertTrue(collectionSettings.isEmpty)
    }

    @discardableResult
    private func makeRepository(configured: Bool = true, remotelyEnabled: Bool = true) -> AnalyticsRepository {
        AnalyticsRepository(
            preferences: preferences.store,
            isConfigured: { configured },
            remotelyEnabled: { remotelyEnabled },
            sendEvent: { [unowned self] in sent.append(($0, $1)) },
            setCollectionEnabled: { [unowned self] in collectionSettings.append($0) }
        )
    }
}
