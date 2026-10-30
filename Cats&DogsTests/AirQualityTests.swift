import XCTest
@testable import Cats_Dogs

final class AirQualityTests: XCTestCase {
    private func us(_ index: Int) -> AirQuality {
        AirQuality(index: index, scale: .us, mainPollutant: nil)
    }

    private func european(_ index: Int) -> AirQuality {
        AirQuality(index: index, scale: .european, mainPollutant: nil)
    }

    func testUSBandsChangeAboveEachBreakpoint() {
        XCTAssertEqual([0, 50, 51, 100, 101, 150, 151, 200, 201, 300, 301, 500].map { us($0).band },
                       [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5])
        XCTAssertEqual(us(42).bandName, "Good")
        XCTAssertEqual(us(128).bandName, "Poor for some")
        XCTAssertEqual(us(400).bandName, "Hazardous")
    }

    func testEuropeanBandsChangeEveryTwenty() {
        XCTAssertEqual([0, 20, 21, 40, 41, 60, 61, 80, 81, 100, 101].map { european($0).band },
                       [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5])
        XCTAssertEqual(european(50).bandName, "Moderate")
        XCTAssertEqual(european(120).bandName, "Extremely poor")
    }

    func testBarPositionSplitsTheBarIntoSixEqualBands() {
        XCTAssertEqual(us(0).barPosition, 0, accuracy: 0.001)
        XCTAssertEqual(us(25).barPosition, 1.0 / 12, accuracy: 0.001)
        XCTAssertEqual(us(100).barPosition, 2.0 / 6, accuracy: 0.001)
        XCTAssertEqual(european(30).barPosition, 1.5 / 6, accuracy: 0.001)
        XCTAssertEqual(us(900).barPosition, 1, "Off the scale stays on the bar")
    }

    func testLinesSpeakOfWalksWithADogAndOfPeopleWithout() {
        XCTAssertEqual(us(42).line(hasDog: true), "Good air for a long walk")
        XCTAssertEqual(us(128).line(hasDog: true), "Short walks for older and flat-faced dogs")
        XCTAssertEqual(us(172).line(hasDog: true), "Potty breaks only today")
        XCTAssertEqual(us(42).line(hasDog: false), "Fresh air all round")
        XCTAssertEqual(us(400).line(hasDog: false), "Stay indoors")
    }

    func testEuropeanCitiesUseTheEuropeanScale() {
        XCTAssertEqual(AirQuality.Scale.forTimeZone("Europe/London"), .european)
        XCTAssertEqual(AirQuality.Scale.forTimeZone("America/New_York"), .us)
        XCTAssertEqual(AirQuality.Scale.forTimeZone(nil), .us)
    }

    func testParsesTheIndexAndNamesTheBiggestPollutantForTheCitysScale() throws {
        let json = """
        {"timezone":"Europe/London","current":{"us_aqi":67,"us_aqi_pm2_5":67,"us_aqi_ozone":1,
        "european_aqi":50,"european_aqi_pm2_5":45,"european_aqi_nitrogen_dioxide":50,"european_aqi_ozone":1}}
        """
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: Data(json.utf8))

        let air = try XCTUnwrap(AirQuality.from(response))

        XCTAssertEqual(air, AirQuality(index: 50, scale: .european, mainPollutant: .nitrogenDioxide))
        XCTAssertEqual(air.pollutantLine, "Mostly nitrogen dioxide")
    }

    func testATieGoesToTheFirstListedPollutant() throws {
        let json = """
        {"timezone":"America/New_York","current":{"us_aqi":46,"us_aqi_pm2_5":46,"us_aqi_ozone":46}}
        """
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: Data(json.utf8))

        XCTAssertEqual(AirQuality.from(response)?.mainPollutant, .fineParticles)
    }

    func testHourlyBandsUseTheCitysScale() throws {
        let json = """
        {"timezone":"Europe/Paris","hourly":{"time":[100,3700],"us_aqi":[40,40],"european_aqi":[50,90]}}
        """
        let response = try JSONDecoder().decode(AirQualityHourlyResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.bandsByHour, [100: 2, 3700: 4])
    }

    func testNoIndexMeansNoReading() throws {
        let json = #"{"timezone":"America/New_York","current":{"us_aqi":null}}"#
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: Data(json.utf8))

        XCTAssertNil(AirQuality.from(response))
    }
}

@MainActor
final class AirQualityViewModelTests: XCTestCase {
    private let london = SavedLocation(label: "London", latitude: 51.51, longitude: -0.13)
    private let response = AirQualityResponse(
        timezone: "America/New_York",
        current: try! JSONDecoder().decode(AirQualityResponse.Current.self, from: Data(#"{"us_aqi":42}"#.utf8))
    )

    func testLoadsAReadingPerCityAndDoesNotRefetchWhileFresh() async {
        var clock = Date(timeIntervalSince1970: 0)
        let calls = Counter()
        let response = self.response
        let viewModel = AirQualityViewModel(fetch: { _, _ in await calls.increment(); return response }, now: { clock }, isEnabled: { true })

        viewModel.load(for: london)
        await waitUntil { viewModel.reading(for: self.london) != nil }
        viewModel.load(for: london)
        await settle()

        XCTAssertEqual(viewModel.reading(for: london)?.index, 42)
        let afterFirst = await calls.value
        XCTAssertEqual(afterFirst, 1)

        clock = clock.addingTimeInterval(AirQualityViewModel.staleAfter)
        viewModel.load(for: london)
        await settle()
        let afterStale = await calls.value
        XCTAssertEqual(afterStale, 2)
    }

    func testCitiesWithoutCoordinatesAreNotFetched() async {
        let calls = Counter()
        let response = self.response
        let viewModel = AirQualityViewModel(fetch: { _, _ in await calls.increment(); return response }, isEnabled: { true })

        viewModel.load(for: SavedLocation(label: "London", latitude: nil, longitude: nil))
        await settle()

        let count = await calls.value
        XCTAssertEqual(count, 0)
    }

    func testNothingIsFetchedWhileOpenMeteoIsSwitchedOff() async {
        let calls = Counter()
        let response = self.response
        let viewModel = AirQualityViewModel(fetch: { _, _ in await calls.increment(); return response }, isEnabled: { false })

        viewModel.load(for: london)
        await settle()

        let count = await calls.value
        XCTAssertEqual(count, 0)
    }

    func testAFailedFetchLeavesNoReading() async {
        let viewModel = AirQualityViewModel(fetch: { _, _ in throw URLError(.notConnectedToInternet) }, isEnabled: { true })

        viewModel.load(for: london)
        await settle()

        XCTAssertNil(viewModel.reading(for: london))
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
