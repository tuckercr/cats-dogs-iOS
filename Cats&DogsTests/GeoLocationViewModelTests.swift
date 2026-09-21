import XCTest
@testable import Cats_Dogs

@MainActor
final class GeoLocationViewModelTests: XCTestCase {
    private var api: ScriptedGeocodingAPI!
    private var viewModel: GeoLocationViewModel!

    override func setUp() async throws {
        api = ScriptedGeocodingAPI()
        viewModel = GeoLocationViewModel(geocodingRepository: api.repository)
    }

    func testShortInputClearsSuggestionsWithoutSearching() async {
        viewModel.onCityInputChange("A")
        await settle()

        XCTAssertEqual(viewModel.cityInput, "A")
        XCTAssertTrue(viewModel.citySuggestions.isEmpty)
        XCTAssertFalse(viewModel.citySuggestLoading)
        XCTAssertTrue(api.queries.isEmpty)
    }

    func testTypingSearchesAfterDebounceAndPublishesSuggestions() async {
        api.onSearch = { _ in [geocodingResult(name: "Austin", state: "Texas")] }

        viewModel.onCityInputChange("  Austin ")
        await waitUntil { !self.viewModel.citySuggestions.isEmpty }

        XCTAssertEqual(api.queries, ["Austin"])
        XCTAssertEqual(viewModel.citySuggestions.map(\.label), ["Austin, Texas, US"])
        XCTAssertFalse(viewModel.citySuggestLoading)
    }

    func testRapidTypingOnlySearchesForTheFinalInput() async {
        api.onSearch = { query in [geocodingResult(name: query)] }

        viewModel.onCityInputChange("Au")
        viewModel.onCityInputChange("Aus")
        viewModel.onCityInputChange("Austin")
        await waitUntil { !self.viewModel.citySuggestions.isEmpty }

        XCTAssertEqual(api.queries, ["Austin"])
    }

    func testLatestCityInputWinsWhenAnEarlierSearchIsStillRunning() async {
        let firstSearch = Gate<[GeocodingDirectDTO]>()
        let secondSearch = Gate<[GeocodingDirectDTO]>()
        api.onSearch = { query in
            try await (query == "Aus" ? firstSearch : secondSearch).value()
        }

        viewModel.onCityInputChange("Aus")
        await waitUntil { self.api.queries == ["Aus"] }
        viewModel.onCityInputChange("Denver")
        await waitUntil { self.api.queries == ["Aus", "Denver"] }

        secondSearch.succeed([geocodingResult(name: "Denver", state: "Colorado")])
        await waitUntil { !self.viewModel.citySuggestions.isEmpty }
        firstSearch.succeed([geocodingResult(name: "Austin", state: "Texas")])
        await settle()

        XCTAssertEqual(viewModel.citySuggestions.map(\.label), ["Denver, Colorado, US"])
        XCTAssertFalse(viewModel.citySuggestLoading)
    }

    func testFailedSearchClearsSuggestionsAndLoading() async {
        api.onSearch = { _ in throw URLError(.notConnectedToInternet) }

        viewModel.onCityInputChange("Austin")
        await waitUntil { self.api.queries.count == 1 && !self.viewModel.citySuggestLoading }

        XCTAssertTrue(viewModel.citySuggestions.isEmpty)
    }

    func testChoosingSuggestionPinsCoordinatesAndManualEditsClearThePin() {
        let suggestion = CitySuggestion(label: "Austin, Texas, US", weatherLat: 30.27, weatherLon: -97.74)

        viewModel.onCitySuggestionChosen(suggestion)

        XCTAssertEqual(viewModel.selectedSuggestion, suggestion)
        XCTAssertEqual(viewModel.cityInput, "Austin, Texas, US")
        XCTAssertTrue(viewModel.citySuggestions.isEmpty)

        viewModel.onCityInputChange("Austin, Texas, U")

        XCTAssertNil(viewModel.selectedSuggestion)
    }

    func testDismissSuggestionsClearsSuggestionsAndLoadingButPreservesInputAndSelection() async {
        api.onSearch = { _ in [geocodingResult(name: "Austin")] }
        viewModel.onCityInputChange("Austin")
        await waitUntil { !self.viewModel.citySuggestions.isEmpty }
        let suggestion = viewModel.citySuggestions[0]
        viewModel.onCitySuggestionChosen(suggestion)

        viewModel.dismissSuggestions()

        XCTAssertTrue(viewModel.citySuggestions.isEmpty)
        XCTAssertFalse(viewModel.citySuggestLoading)
        XCTAssertEqual(viewModel.cityInput, suggestion.label)
        XCTAssertEqual(viewModel.selectedSuggestion, suggestion)
    }

    func testResetClearsAllStateAndCancelsPendingSearch() async {
        viewModel.onCitySuggestionChosen(CitySuggestion(label: "Austin", weatherLat: 1, weatherLon: 2))
        viewModel.onCityInputChange("Denver")

        viewModel.reset()
        try? await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(viewModel.cityInput, "")
        XCTAssertTrue(viewModel.citySuggestions.isEmpty)
        XCTAssertFalse(viewModel.citySuggestLoading)
        XCTAssertNil(viewModel.selectedSuggestion)
        XCTAssertTrue(api.queries.isEmpty)
    }
}
