import XCTest
@testable import Cats_Dogs

@MainActor
final class NotificationWorkerLogicTests: XCTestCase {
    private let london = SavedLocation(label: "London, GB", latitude: 51.5074, longitude: -0.1278)

    func testReturnsSuccessWhenNoLocationsSaved() async {
        var posted: [(String, String)] = []
        let logic = makeLogic(
            savedLocations: [],
            postNotification: { posted.append(($0, $1)) }
        )

        let result = await logic.doWork()

        XCTAssertEqual(result, .success)
        XCTAssertTrue(posted.isEmpty)
    }

    func testReturnsSuccessWhenActiveIndexOutOfBounds() async {
        var posted: [(String, String)] = []
        let logic = makeLogic(
            savedLocations: [london],
            activeIndex: 5,
            postNotification: { posted.append(($0, $1)) }
        )

        let result = await logic.doWork()

        XCTAssertEqual(result, .success)
        XCTAssertTrue(posted.isEmpty)
    }

    func testReturnsRetryWhenWeatherFetchFails() async {
        let logic = makeLogic(
            fetchCurrentWeather: { _, _, _, _ in .failure(OpenWeatherClientError.network) }
        )

        let result = await logic.doWork()

        XCTAssertEqual(result, .retry)
    }

    func testPostsNotificationWhenWeatherFetchSucceeds() async {
        var posted: [(String, String)] = []
        let logic = makeLogic(postNotification: { posted.append(($0, $1)) })

        let result = await logic.doWork()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(posted.count, 1)
    }

    func testDoesNotPostWhenPermissionDenied() async {
        var posted: [(String, String)] = []
        let logic = makeLogic(
            hasNotificationPermission: { false },
            postNotification: { posted.append(($0, $1)) }
        )

        let result = await logic.doWork()

        XCTAssertEqual(result, .success)
        XCTAssertTrue(posted.isEmpty)
    }

    func testBuildNotificationContentUsesForecastHighLow() {
        let weather = Self.sampleWeather()
        let forecast = DayForecast(
            dateLabel: "Mon, Jan 1",
            conditionMain: "Clouds",
            description: "broken clouds",
            iconCode: "04d",
            temperature: 10,
            feelsLike: 9,
            tempMin: 5,
            tempMax: 12,
            units: .metric,
            hourlySlots: []
        )

        let content = buildNotificationContent(weather: weather, todayForecast: forecast)

        XCTAssertEqual(content.title, "15° in London")
        XCTAssertEqual(content.body, "12°/5° • Clear Sky")
    }

    private func makeLogic(
        savedLocations: [SavedLocation]? = nil,
        activeIndex: Int = 0,
        fetchCurrentWeather: (
            (WeatherUnits, String, Double?, Double?) async -> Result<CurrentWeather, Error>
        )? = nil,
        fetchForecast: (
            (WeatherUnits, String, Double?, Double?) async -> Result<[DayForecast], Error>
        )? = nil,
        hasNotificationPermission: @escaping () -> Bool = { true },
        postNotification: @escaping (String, String) -> Void = { _, _ in }
    ) -> NotificationWorkerLogic {
        NotificationWorkerLogic(
            getSavedLocations: { savedLocations ?? [self.london] },
            getActiveIndex: { activeIndex },
            getUnits: { .metric },
            fetchCurrentWeather: fetchCurrentWeather ?? { _, _, _, _ in .success(Self.sampleWeather()) },
            fetchForecast: fetchForecast ?? { _, _, _, _ in .success([]) },
            hasNotificationPermission: hasNotificationPermission,
            postNotification: postNotification
        )
    }

    private static func sampleWeather() -> CurrentWeather {
        CurrentWeather(
            cityName: "London",
            conditionMain: "Clear",
            description: "clear sky",
            iconCode: "01d",
            temperature: 15.4,
            feelsLike: 14.0,
            tempMin: 10,
            tempMax: 18,
            humidityPercent: 50,
            pressureHpa: 1013,
            windSpeed: 3.0,
            windDeg: 180,
            visibilityMeters: 10_000,
            cloudPercent: 10,
            units: .metric,
            sunriseEpoch: nil,
            sunsetEpoch: nil
        )
    }
}
