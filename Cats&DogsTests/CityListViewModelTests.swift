import XCTest
@testable import Cats_Dogs

@MainActor
final class CityListViewModelTests: XCTestCase {
    private let austin = SavedLocation(label: "Austin", latitude: 30.27, longitude: -97.74)
    private let denver = SavedLocation(label: "Denver", latitude: 39.74, longitude: -104.99)
    private let seattle = SavedLocation(label: "Seattle", latitude: 47.61, longitude: -122.33)

    private var preferences: IsolatedPreferences!
    private var geocoding: ScriptedGeocodingAPI!

    override func setUp() async throws {
        preferences = IsolatedPreferences()
        geocoding = ScriptedGeocodingAPI()
    }

    override func tearDown() async throws {
        preferences.destroy()
    }

    // MARK: - init

    func testInitLoadsSavedLocationsAndActiveIndex() {
        preferences.store.setSavedLocations([austin, denver])
        preferences.store.setActiveLocationIndex(1)

        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.locations, [austin, denver])
        XCTAssertEqual(viewModel.activeIndex, 1)
        XCTAssertEqual(viewModel.activeLocation, denver)
    }

    func testInitWithNoSavedLocationsMigratesFromLegacyLastCity() {
        preferences.store.setLastCity("Portland")

        let viewModel = makeViewModel()

        let migrated = SavedLocation(label: "Portland", latitude: nil, longitude: nil)
        XCTAssertEqual(viewModel.locations, [migrated])
        XCTAssertEqual(viewModel.activeLocation, migrated)
        XCTAssertEqual(preferences.reopened().savedLocations, [migrated])
    }

    func testInitWithNoSavedLocationsAndNoLastCityLeavesLocationsEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.locations.isEmpty)
        XCTAssertNil(viewModel.activeLocation)
    }

    func testInitClampsOutOfRangeActiveIndex() {
        preferences.store.setSavedLocations([austin, denver])
        preferences.store.setActiveLocationIndex(9)

        XCTAssertEqual(makeViewModel().activeIndex, 1)
    }

    // MARK: - addLocation

    func testAddLocationAppendsNewEntryMakesItActiveAndPersists() async {
        preferences.store.setSavedLocations([austin])
        let viewModel = makeViewModel()

        viewModel.addLocation(denver)
        await waitUntil { viewModel.locations.count == 2 }

        XCTAssertEqual(viewModel.locations, [austin, denver])
        XCTAssertEqual(viewModel.activeLocation, denver)
        XCTAssertEqual(preferences.reopened().savedLocations, [austin, denver])
        XCTAssertEqual(preferences.reopened().activeLocationIndex, 1)
        XCTAssertTrue(geocoding.queries.isEmpty, "Locations that already have coordinates must not be geocoded")
    }

    func testAddLocationWithoutCoordinatesGeocodesThemAndKeepsTheEnteredLabel() async {
        geocoding.onSearch = { _ in [geocodingResult(name: "Paris", country: "FR", lat: 48.85, lon: 2.35)] }
        let viewModel = makeViewModel()

        viewModel.addLocation(SavedLocation(label: "paris", latitude: nil, longitude: nil))
        await waitUntil { viewModel.locations.count == 1 }

        XCTAssertEqual(geocoding.queries, ["paris"])
        XCTAssertEqual(viewModel.locations, [SavedLocation(label: "paris", latitude: 48.85, longitude: 2.35)])
    }

    func testAddLocationWithoutCoordinatesIsStillSavedWhenGeocodingFails() async {
        geocoding.onSearch = { _ in throw URLError(.notConnectedToInternet) }
        let viewModel = makeViewModel()

        viewModel.addLocation(SavedLocation(label: "Nowhere", latitude: nil, longitude: nil))
        await waitUntil { viewModel.locations.count == 1 }

        XCTAssertEqual(viewModel.locations, [SavedLocation(label: "Nowhere", latitude: nil, longitude: nil)])
    }

    func testAddLocationWithDuplicateLabelSwitchesToExistingInsteadOfDuplicating() async {
        preferences.store.setSavedLocations([austin, denver])
        preferences.store.setActiveLocationIndex(1)
        let viewModel = makeViewModel()

        viewModel.addLocation(SavedLocation(label: "Austin", latitude: 1, longitude: 2))
        await settle()

        XCTAssertEqual(viewModel.locations, [austin, denver])
        XCTAssertEqual(viewModel.activeIndex, 0)
    }

    /// Regression: the geocoded label used to replace the typed one, defeating the duplicate check.
    func testReAddingAGeocodedNameOnlyCityDoesNotDuplicateIt() async {
        geocoding.onSearch = { _ in [geocodingResult(name: "Paris", country: "FR", lat: 48.85, lon: 2.35)] }
        let viewModel = makeViewModel()
        viewModel.addLocation(SavedLocation(label: "paris", latitude: nil, longitude: nil))
        await waitUntil { viewModel.locations.count == 1 }

        viewModel.addLocation(SavedLocation(label: "paris", latitude: nil, longitude: nil))
        await settle()

        XCTAssertEqual(viewModel.locations.count, 1)
        XCTAssertEqual(geocoding.queries.count, 1)
    }

    // MARK: - removeLocation

    func testRemoveLocationRemovesEntryAtIndexAndPersists() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        let viewModel = makeViewModel()

        viewModel.removeLocation(at: 1)

        XCTAssertEqual(viewModel.locations, [austin, seattle])
        XCTAssertEqual(preferences.reopened().savedLocations, [austin, seattle])
    }

    func testRemoveLocationClampsActiveIndexWhenActiveTabIsRemoved() {
        preferences.store.setSavedLocations([austin, denver])
        preferences.store.setActiveLocationIndex(1)
        let viewModel = makeViewModel()

        viewModel.removeLocation(at: 1)

        XCTAssertEqual(viewModel.activeIndex, 0)
        XCTAssertEqual(viewModel.activeLocation, austin)
        XCTAssertEqual(preferences.reopened().activeLocationIndex, 0)
    }

    func testRemoveLocationOnLastEntryResultsInEmptyListAndNilActiveLocation() {
        preferences.store.setSavedLocations([austin])
        let viewModel = makeViewModel()

        viewModel.removeLocation(at: 0)

        XCTAssertTrue(viewModel.locations.isEmpty)
        XCTAssertNil(viewModel.activeLocation)
    }

    func testRemoveLocationIgnoresOutOfRangeIndex() {
        preferences.store.setSavedLocations([austin])
        let viewModel = makeViewModel()

        viewModel.removeLocation(at: 4)

        XCTAssertEqual(viewModel.locations, [austin])
    }

    // MARK: - setActiveIndex

    func testSetActiveIndexUpdatesIndexAndPersists() {
        preferences.store.setSavedLocations([austin, denver])
        let viewModel = makeViewModel()

        viewModel.setActiveIndex(1)

        XCTAssertEqual(viewModel.activeLocation, denver)
        XCTAssertEqual(preferences.reopened().activeLocationIndex, 1)
    }

    func testSetActiveIndexIgnoresOutOfRangeIndex() {
        preferences.store.setSavedLocations([austin, denver])
        let viewModel = makeViewModel()

        viewModel.setActiveIndex(7)

        XCTAssertEqual(viewModel.activeIndex, 0)
        XCTAssertEqual(preferences.reopened().activeLocationIndex, 0)
    }

    // MARK: - reorderLocations (destination uses SwiftUI onMove semantics: the offset before removal)

    func testReorderLocationsMovesItemAndPersistsNewOrder() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(viewModel.locations, [denver, seattle, austin])
        XCTAssertEqual(preferences.reopened().savedLocations, [denver, seattle, austin])
    }

    func testReorderLocationsTracksActiveLocationWhenItMoves() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(viewModel.activeLocation, austin)
        XCTAssertEqual(preferences.reopened().activeLocationIndex, 2)
    }

    func testReorderLocationsAdjustsActiveIndexWhenItemMovesOverItFromBelow() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        preferences.store.setActiveLocationIndex(1)
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(viewModel.locations, [denver, seattle, austin])
        XCTAssertEqual(viewModel.activeLocation, denver)
    }

    func testReorderLocationsAdjustsActiveIndexWhenItemMovesOverItFromAbove() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        preferences.store.setActiveLocationIndex(1)
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.locations, [seattle, austin, denver])
        XCTAssertEqual(viewModel.activeLocation, denver)
    }

    func testReorderLocationsLeavesActiveIndexAloneWhenMoveDoesNotCrossIt() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 1), to: 3)

        XCTAssertEqual(viewModel.locations, [austin, seattle, denver])
        XCTAssertEqual(viewModel.activeLocation, austin)
    }

    func testDroppingAnItemBackInPlaceChangesNothing() {
        preferences.store.setSavedLocations([austin, denver, seattle])
        let viewModel = makeViewModel()

        viewModel.reorderLocations(from: IndexSet(integer: 1), to: 1)

        XCTAssertEqual(viewModel.locations, [austin, denver, seattle])
    }

    private func makeViewModel() -> CityListViewModel {
        CityListViewModel(preferences: preferences.store, geocodingRepository: geocoding.repository)
    }
}
