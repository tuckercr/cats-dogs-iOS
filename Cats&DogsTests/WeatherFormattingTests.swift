import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherFormattingTests: XCTestCase {
    /// 2023-11-14 22:13:20 UTC
    private let epoch = 1_700_000_000

    func testEpochTimeIsFormattedInTheGivenTimeZone() {
        let utc = WeatherFormatting.epochTime(epoch, timeZone: TimeZone(secondsFromGMT: 0)!)
        let tokyo = WeatherFormatting.epochTime(epoch, timeZone: TimeZone(secondsFromGMT: 9 * 3600)!)

        XCTAssertTrue(utc.hasPrefix("10:13"), utc)
        XCTAssertTrue(tokyo.hasPrefix("7:13"), tokyo)
    }

    func testCurrentWeatherUsesTheCitysOffsetFromTheApi() async {
        let api = ScriptedWeatherAPI()
        api.onCurrent = { _ in
            var response = weatherResponse(name: "Tokyo")
            response.timezone = 9 * 3600
            return response
        }

        let weather = try? await api.repository.fetchCurrentWeather(
            units: .metric, locationLabel: "Tokyo", cityQuery: "Tokyo", latitude: nil, longitude: nil
        ).get()

        XCTAssertEqual(weather?.timezoneOffsetSeconds, 32_400)
        XCTAssertEqual(weather?.timeZone.secondsFromGMT(), 32_400)
    }

    func testWeatherCachedBeforeTheOffsetExistedFallsBackToTheDeviceTimeZone() async {
        let weather = await makeCurrentWeather()

        XCTAssertNil(weather.timezoneOffsetSeconds)
        XCTAssertEqual(weather.timeZone, .current)
    }

    func testTimezoneIsDecodedFromTheApiPayload() throws {
        let json = """
        {"name":"Tokyo","weather":[{"main":"Clear","description":"clear sky","icon":"01d"}],
         "main":{"temp":20,"feels_like":19,"temp_min":18,"temp_max":22,"humidity":50,"pressure":1012},
         "wind":{"speed":2.0},"timezone":32400}
        """
        let response = try JSONDecoder().decode(CurrentWeatherResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.timezone, 32_400)
    }

    func testUVIndexUsesTheWHOCategories() {
        XCTAssertEqual(WeatherFormatting.uvIndex(0.4), "0 (Low)")
        XCTAssertEqual(WeatherFormatting.uvIndex(2.4), "2 (Low)")
        XCTAssertEqual(WeatherFormatting.uvIndex(4.6), "5 (Moderate)")
        XCTAssertEqual(WeatherFormatting.uvIndex(6), "6 (High)")
        XCTAssertEqual(WeatherFormatting.uvIndex(9), "9 (Very high)")
        XCTAssertEqual(WeatherFormatting.uvIndex(11.2), "11 (Extreme)")
    }
}
