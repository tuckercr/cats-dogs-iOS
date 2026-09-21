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
}
