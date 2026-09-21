import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherForecastViewModelTests: XCTestCase {
    private let austin = SavedLocation(label: "Austin", latitude: nil, longitude: nil)
    private let denver = SavedLocation(label: "Denver", latitude: nil, longitude: nil)
    private let pinned = SavedLocation(label: "Austin, Texas, US", latitude: 30.27, longitude: -97.74)
    private let offline = OpenWeatherClientError.network

    private var preferences: IsolatedPreferences!
    private var api: ScriptedWeatherAPI!
    private var viewModel: WeatherForecastViewModel!

    override func setUp() async throws {
        preferences = IsolatedPreferences()
        preferences.store.setUnitOverride(.metric)
        api = ScriptedWeatherAPI()
        viewModel = WeatherForecastViewModel(preferences: preferences.store, weatherRepository: api.repository)
    }

    override func tearDown() async throws {
        preferences.destroy()
    }

    // MARK: - Request routing

    func testCurrentWeatherWithCoordinatesPassesLatLonAndNilCityQuery() async {
        viewModel.refreshCurrent(location: pinned)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        XCTAssertEqual(
            api.currentRequests,
            [WeatherRequest(cityQuery: nil, latitude: 30.27, longitude: -97.74, units: .metric)]
        )
        XCTAssertEqual(viewModel.currentWeather.successValue?.cityName, "Austin, Texas, US")
    }

    func testCurrentWeatherWithoutCoordinatesUsesLabelAsCityQuery() async {
        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        XCTAssertEqual(
            api.currentRequests,
            [WeatherRequest(cityQuery: "Austin", latitude: nil, longitude: nil, units: .metric)]
        )
    }

    func testForecastWithCoordinatesPassesLatLonAndNilCityQuery() async {
        viewModel.refreshForecast(location: pinned)
        await waitUntil { self.viewModel.forecast.successValue != nil }

        XCTAssertEqual(
            api.forecastRequests,
            [WeatherRequest(cityQuery: nil, latitude: 30.27, longitude: -97.74, units: .metric)]
        )
    }

    func testRequestsUseTheUnitOverrideFromSettings() async {
        preferences.store.setUnitOverride(.imperial)

        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        XCTAssertEqual(api.currentRequests.first?.units, .imperial)
        XCTAssertEqual(viewModel.currentWeather.successValue?.units, .imperial)
    }

    func testRefreshAfterAUnitChangeReplacesDataCachedInTheOldUnits() async {
        viewModel.refreshCurrent(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }
        XCTAssertEqual(viewModel.currentWeather.successValue?.units, .metric)

        preferences.store.setUnitOverride(.imperial)
        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.viewModel.currentWeather.successValue?.units == .imperial }

        XCTAssertEqual(api.currentRequests.map(\.units), [.metric, .imperial])
        XCTAssertEqual(preferences.store.cachedWeather(for: austin.cacheKey)?.units, .imperial)
    }

    func testCurrentLocationShowsTheCityNameDetectedByTheApi() async {
        api.onCurrent = { _ in weatherResponse(name: "Detected City") }
        let myLocation = SavedLocation(label: "My Location", latitude: 37.77, longitude: -122.42, isCurrentLocation: true)

        viewModel.refreshCurrent(location: myLocation)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        XCTAssertEqual(viewModel.currentWeather.successValue?.cityName, "Detected City")
    }

    // MARK: - Foreground refresh

    func testSuccessfulRefreshCachesResultAndRemembersLastCity() async {
        viewModel.refreshCurrent(location: austin)
        viewModel.refreshForecast(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(preferences.store.cachedWeather(for: austin.cacheKey)?.cityName, "Austin")
        XCTAssertEqual(preferences.store.cachedForecast(for: austin.cacheKey)?.count, 1)
        XCTAssertEqual(preferences.store.lastCity, "Austin")
    }

    func testIsRefreshingStaysTrueUntilBothCurrentAndForecastFinish() async {
        let forecastGate = Gate<ForecastResponse>()
        api.onForecast = { _ in try await forecastGate.value() }

        viewModel.refreshCurrent(location: austin)
        viewModel.refreshForecast(location: austin)
        XCTAssertTrue(viewModel.isRefreshing)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }
        await settle()
        XCTAssertTrue(viewModel.isRefreshing, "Forecast is still in flight")

        forecastGate.succeed(forecastResponse())
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertNotNil(viewModel.forecast.successValue)
    }

    func testLatestCurrentWeatherRequestWinsWhenAnEarlierRequestFinishesLast() async {
        let firstRequest = Gate<CurrentWeatherResponse>()
        let secondRequest = Gate<CurrentWeatherResponse>()
        api.onCurrent = { request in
            try await (request.cityQuery == "Austin" ? firstRequest : secondRequest).value()
        }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 1 }
        viewModel.refreshCurrent(location: denver)
        await waitUntil { self.api.currentRequests.count == 2 }

        secondRequest.succeed(weatherResponse(name: "Denver"))
        await waitUntil { self.viewModel.currentWeather.successValue != nil }
        firstRequest.succeed(weatherResponse(name: "Austin"))
        await settle()

        XCTAssertEqual(api.currentRequests.map(\.cityQuery), ["Austin", "Denver"])
        XCTAssertEqual(viewModel.currentWeather.successValue?.cityName, "Denver")
        XCTAssertEqual(preferences.store.lastCity, "Denver")
        XCTAssertNil(preferences.store.cachedWeather(for: austin.cacheKey), "The stale result must not be cached")
        XCTAssertFalse(viewModel.isRefreshing)
    }

    // MARK: - Errors

    func testCurrentWeatherNetworkFailureMapsToRetryableErrorAndCanBeCleared() async {
        api.onCurrent = { _ in throw self.offline }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather, .error(errorKey: "offline", canRetry: true))

        viewModel.clearCurrentError()
        XCTAssertEqual(viewModel.currentWeather, .idle)
    }

    func testForecastNetworkFailureMapsToRetryableErrorAndCanBeCleared() async {
        api.onForecast = { _ in throw self.offline }

        viewModel.refreshForecast(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.forecast, .error(errorKey: "offline", canRetry: true))

        viewModel.clearForecastError()
        XCTAssertEqual(viewModel.forecast, .idle)
    }

    func testCityNotFoundIsNotRetryable() async {
        api.onCurrent = { _ in throw OpenWeatherClientError.http(statusCode: 404, message: "city not found") }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather, .error(errorKey: "city_not_found", canRetry: false))
    }

    func testClearErrorLeavesSuccessfulStateAlone() async {
        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        viewModel.clearCurrentError()

        XCTAssertNotNil(viewModel.currentWeather.successValue)
    }

    // MARK: - Cache

    func testCachedCurrentWeatherIsShownImmediatelyWhileFetchIsInFlight() async {
        preferences.store.setCachedWeather(await makeCurrentWeather(temperature: 5), for: austin.cacheKey)
        let gate = Gate<CurrentWeatherResponse>()
        api.onCurrent = { _ in try await gate.value() }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 1 }

        XCTAssertEqual(viewModel.currentWeather.successValue?.temperature, 5)
        XCTAssertTrue(viewModel.isRefreshing)

        gate.succeed(weatherResponse(name: "Austin", temperature: 25))
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather.successValue?.temperature, 25)
    }

    func testNetworkErrorIsSuppressedWhenCachedCurrentWeatherIsAvailable() async {
        preferences.store.setCachedWeather(await makeCurrentWeather(temperature: 5), for: austin.cacheKey)
        api.onCurrent = { _ in throw self.offline }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather.successValue?.temperature, 5)
    }

    func testNetworkErrorIsSuppressedWhenCachedForecastIsAvailable() async {
        let cached = await makeForecast(temperature: 7)
        preferences.store.setCachedForecast(cached, for: austin.cacheKey)
        api.onForecast = { _ in throw self.offline }

        viewModel.refreshForecast(location: austin)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.forecast, .success(cached))
    }

    func testCacheIsKeptPerLocation() async {
        preferences.store.setCachedWeather(await makeCurrentWeather(temperature: 5), for: austin.cacheKey)
        api.onCurrent = { _ in throw self.offline }

        viewModel.refreshCurrent(location: denver)
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather, .error(errorKey: "offline", canRetry: true))
    }

    // MARK: - Silent background refresh

    func testBackgroundRefreshCurrentUpdatesStateOnSuccessWithoutShowingLoading() async {
        viewModel.backgroundRefreshCurrent(location: austin)
        XCTAssertEqual(viewModel.currentWeather, .idle)
        await waitUntil { self.viewModel.currentWeather.successValue != nil }

        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertNotNil(preferences.store.cachedWeather(for: austin.cacheKey))
    }

    func testBackgroundRefreshCurrentSilentlyIgnoresNetworkFailures() async {
        api.onCurrent = { _ in throw self.offline }

        viewModel.backgroundRefreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 1 }
        await settle()

        XCTAssertEqual(viewModel.currentWeather, .idle)
    }

    func testBackgroundRefreshForecastUpdatesStateOnSuccessWithoutShowingLoading() async {
        viewModel.backgroundRefreshForecast(location: austin)
        XCTAssertEqual(viewModel.forecast, .idle)
        await waitUntil { self.viewModel.forecast.successValue != nil }

        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertNotNil(preferences.store.cachedForecast(for: austin.cacheKey))
    }

    func testBackgroundRefreshForecastSilentlyIgnoresNetworkFailures() async {
        api.onForecast = { _ in throw self.offline }

        viewModel.backgroundRefreshForecast(location: austin)
        await waitUntil { self.api.forecastRequests.count == 1 }
        await settle()

        XCTAssertEqual(viewModel.forecast, .idle)
    }

    /// Reproduces Android's indefinite-spinner bug: a foreground refresh and a silent background
    /// refresh fire for the same location, and the background one fails.
    func testConcurrentSameLocationBackgroundRefreshDoesNotBlockForegroundResult() async {
        let foreground = Gate<CurrentWeatherResponse>()
        let background = Gate<CurrentWeatherResponse>()
        var call = 0
        api.onCurrent = { _ in
            call += 1
            return try await (call == 1 ? foreground : background).value()
        }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 1 }
        viewModel.backgroundRefreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 2 }

        background.fail(offline)
        await settle()
        foreground.succeed(weatherResponse(name: "Austin"))
        await waitUntil { !self.viewModel.isRefreshing }

        XCTAssertEqual(viewModel.currentWeather.successValue?.cityName, "Austin")
    }

    func testStaleBackgroundCurrentRefreshDoesNotOverwriteNewerForegroundResult() async {
        let austinGate = Gate<CurrentWeatherResponse>()
        api.onCurrent = { request in
            request.cityQuery == "Austin" ? try await austinGate.value() : weatherResponse(name: "Denver")
        }

        viewModel.refreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 1 }
        viewModel.backgroundRefreshCurrent(location: austin)
        await waitUntil { self.api.currentRequests.count == 2 }
        viewModel.refreshCurrent(location: denver)
        await waitUntil { self.viewModel.currentWeather.successValue?.cityName == "Denver" }

        austinGate.succeed(weatherResponse(name: "Austin"))
        await settle()

        XCTAssertEqual(viewModel.currentWeather.successValue?.cityName, "Denver")
    }

    func testStaleBackgroundForecastRefreshDoesNotOverwriteNewerForegroundResult() async {
        let austinGate = Gate<ForecastResponse>()
        api.onForecast = { request in
            request.cityQuery == "Austin" ? try await austinGate.value() : forecastResponse(temperature: 30)
        }
        let denverForecast = await makeForecast(temperature: 30)

        viewModel.refreshForecast(location: austin)
        await waitUntil { self.api.forecastRequests.count == 1 }
        viewModel.backgroundRefreshForecast(location: austin)
        await waitUntil { self.api.forecastRequests.count == 2 }
        viewModel.refreshForecast(location: denver)
        await waitUntil { self.viewModel.forecast == .success(denverForecast) }

        austinGate.succeed(forecastResponse(temperature: -5))
        await settle()

        XCTAssertEqual(viewModel.forecast, .success(denverForecast))
    }
}
