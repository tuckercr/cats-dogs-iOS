import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherBackgroundRefresherTests: XCTestCase {
    private let london = SavedLocation(label: "London, GB", latitude: 51.5074, longitude: -0.1278)
    private let nameOnly = SavedLocation(label: "Paris", latitude: nil, longitude: nil)

    private var suiteName: String!
    private var preferences: PreferencesStore!

    override func setUp() async throws {
        suiteName = "WeatherBackgroundRefresherTests-\(UUID().uuidString)"
        preferences = PreferencesStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func testRefreshCachesFreshDataAndReschedulesNotifications() async {
        preferences.setSavedLocations([london])
        let api = FakeOpenWeatherAPI()
        var scheduled: [(title: String, body: String)] = []
        let refresher = makeRefresher(api: api, onSchedule: { scheduled.append(($0, $1)) })

        let result = await refresher.performRefresh()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(preferences.cachedWeather(for: london.cacheKey)?.temperature, 72.5)
        XCTAssertEqual(preferences.cachedForecast(for: london.cacheKey)?.count, 1)
        XCTAssertEqual(api.lastCurrentLatitude, 51.5074)
        XCTAssertNil(api.lastCurrentCityQuery)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled.first?.title, "73° in London, GB")
    }

    func testRefreshStillCachesWhenNotificationsAreNotAuthorized() async {
        preferences.setSavedLocations([london])
        var scheduled = 0
        let refresher = makeRefresher(authorized: false, onSchedule: { _, _ in scheduled += 1 })

        let result = await refresher.performRefresh()

        XCTAssertEqual(result, .success)
        XCTAssertNotNil(preferences.cachedWeather(for: london.cacheKey))
        XCTAssertEqual(scheduled, 0)
    }

    func testRefreshOnlyTouchesTheActiveLocation() async {
        preferences.setSavedLocations([london, nameOnly])
        preferences.setActiveLocationIndex(1)
        let api = FakeOpenWeatherAPI()
        let refresher = makeRefresher(api: api)

        await refresher.performRefresh()

        XCTAssertEqual(api.lastCurrentCityQuery, "Paris")
        XCTAssertNil(api.lastCurrentLatitude)
        XCTAssertNotNil(preferences.cachedWeather(for: nameOnly.cacheKey))
        XCTAssertNil(preferences.cachedWeather(for: london.cacheKey))
    }

    func testFailedFetchKeepsExistingCacheAndRetriesSooner() async {
        preferences.setSavedLocations([london])
        _ = await makeRefresher().performRefresh()
        var scheduled = 0
        var requestedDelays: [TimeInterval] = []
        let refresher = makeRefresher(
            api: FakeOpenWeatherAPI(currentError: URLError(.notConnectedToInternet)),
            onSchedule: { _, _ in scheduled += 1 },
            onSubmit: { requestedDelays.append($0.timeIntervalSinceNow) }
        )

        await refresher.handleAppRefresh()

        XCTAssertNotNil(preferences.cachedWeather(for: london.cacheKey))
        XCTAssertEqual(scheduled, 0)
        XCTAssertEqual(requestedDelays.count, 2)
        XCTAssertEqual(requestedDelays[0], WeatherBackgroundRefresher.refreshInterval, accuracy: 5)
        XCTAssertEqual(requestedDelays[1], WeatherBackgroundRefresher.retryInterval, accuracy: 5)
    }

    func testSuccessfulRefreshQueuesExactlyOneFollowUp() async {
        preferences.setSavedLocations([london])
        var requestedDelays: [TimeInterval] = []
        let refresher = makeRefresher(onSubmit: { requestedDelays.append($0.timeIntervalSinceNow) })

        await refresher.handleAppRefresh()

        XCTAssertEqual(requestedDelays.count, 1)
        XCTAssertEqual(requestedDelays[0], WeatherBackgroundRefresher.refreshInterval, accuracy: 5)
    }

    func testNoSavedLocationsDoesNoNetworkWork() async {
        let api = FakeOpenWeatherAPI()
        let refresher = makeRefresher(api: api)

        let result = await refresher.performRefresh()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(api.currentWeatherCallCount, 0)
    }

    private func makeRefresher(
        api: FakeOpenWeatherAPI? = nil,
        authorized: Bool = true,
        onSchedule: @escaping (String, String) -> Void = { _, _ in },
        onSubmit: @escaping (Date) -> Void = { _ in }
    ) -> WeatherBackgroundRefresher {
        WeatherBackgroundRefresher(
            preferences: preferences,
            weatherRepository: WeatherRepository(
                client: api ?? FakeOpenWeatherAPI(),
                openMeteo: StubOpenMeteoAPI(response: openMeteoResponse(hours: 1)),
                timeZone: TimeZone(identifier: "UTC")!,
                now: { Date(timeIntervalSince1970: TimeInterval(fixtureDayStart)) }
            ),
            notificationsAuthorized: { authorized },
            scheduleNotifications: { title, body in onSchedule(title, body) },
            submitRefreshRequest: onSubmit
        )
    }
}

private final class FakeOpenWeatherAPI: OpenWeatherAPI, @unchecked Sendable {
    var currentWeatherCallCount = 0
    var lastCurrentCityQuery: String?
    var lastCurrentLatitude: Double?

    private let currentError: Error?

    init(currentError: Error? = nil) {
        self.currentError = currentError
    }

    func currentWeather(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> CurrentWeatherResponse {
        currentWeatherCallCount += 1
        lastCurrentCityQuery = cityQuery
        lastCurrentLatitude = latitude
        if let currentError { throw currentError }
        return CurrentWeatherResponse(
            name: "OpenWeather City",
            weather: [WeatherDescDTO(main: "Clear", description: "clear sky", icon: "01d")],
            main: MainDTO(temp: 72.5, feelsLike: 70.0, humidity: 42),
            wind: WindDTO(speed: 5.5),
            visibility: 10_000,
            clouds: CloudsDTO(all: 25),
            sys: nil
        )
    }

    func forecast(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> ForecastResponse {
        ForecastResponse(list: [
            ForecastListItemDTO(
                dt: 1_700_049_600,
                main: MainDTO(temp: 70.0, feelsLike: 69.0, humidity: 50),
                weather: [WeatherDescDTO(main: "Clear", description: "clear sky", icon: "01d")],
                wind: WindDTO(speed: 1.0)
            ),
        ])
    }
}
