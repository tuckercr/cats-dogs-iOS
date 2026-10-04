import XCTest
@testable import Cats_Dogs

@MainActor
final class OpenMeteoForecastTests: XCTestCase {
    private let dayStart = fixtureDayStart // 2024-01-01T00:00:00Z

    private func days(_ response: OpenMeteoResponse, units: WeatherUnits = .metric, now: Int? = nil) -> [DayForecast] {
        OpenMeteoForecast.dayForecasts(
            from: response,
            units: units,
            now: Date(timeIntervalSince1970: TimeInterval(now ?? dayStart))
        )
    }

    func testDropsHoursBeforeTheCurrentHour() {
        // "Now" is 05:30, so the 00:00-04:00 hours are gone and the first slot is 05:00.
        let result = days(openMeteoResponse(hours: 24), now: dayStart + 5 * 3600 + 1800)

        XCTAssertEqual(result.flatMap(\.hourlySlots).count, 19)
        XCTAssertEqual(result.first?.hourlySlots.first?.timeLabel, "5 AM")
    }

    func testGroupsAndLabelsHoursInTheCitysOwnTimeZone() {
        // UTC+10: midnight UTC is 10 AM local, and 14:00 UTC is midnight on the next local day.
        let result = days(openMeteoResponse(hours: 24, offset: 36_000))

        XCTAssertEqual(result.first?.hourlySlots.first?.timeLabel, "10 AM")
        XCTAssertEqual(result.count, 2)
    }

    func testMapsWeatherCodeRainChanceAndDailyPeakUV() {
        let day = days(openMeteoResponse(hours: 6)).first

        XCTAssertEqual(day?.conditionMain, "Rain")
        XCTAssertEqual(day?.precipitationChance, 40)
        XCTAssertEqual(day?.uvIndexMax, 5)
        XCTAssertEqual(day?.hourlySlots.first?.iconCode, "10d")
    }

    func testPavementHeatIsEstimatedInTheRequestedUnits() {
        // 86F = 30C air; 800 W/m2 adds 28C -> 58C = 136.4F.
        let slot = days(openMeteoResponse(hours: 1, temperature: 86, radiation: 800), units: .imperial)
            .first?.hourlySlots.first

        XCTAssertEqual(slot?.pavementTemperature ?? 0, 136.4, accuracy: 0.01)
    }

    func testKeepsTheCurrentHourInAHalfHourTimeZone() {
        // India (+5:30): slots start at xx:30 UTC. At 10:40 local (05:10 UTC) the 10:00 local slot
        // (04:30 UTC) is the current hour and must stay.
        let response = openMeteoResponse(hours: 24, start: dayStart - 1800, offset: 19_800, zone: "Asia/Kolkata")
        let first = days(response, now: dayStart + 5 * 3600 + 600).first?.hourlySlots.first

        XCTAssertEqual(first?.timeLabel, "10 AM")
        XCTAssertEqual(first?.localHour, 10)
    }

    func testLabelsFollowADSTChangeInsideTheForecastWindow() {
        // London leaves BST at 01:00 UTC on 2026-10-25. Fetched before, with offset +3600, the
        // 12:00 UTC slot after the change must read noon, not 1 PM.
        let noonUTCAfter = 1_792_929_600 // 2026-10-25T12:00:00Z
        let response = openMeteoResponse(hours: 1, start: noonUTCAfter, offset: 3600, zone: "Europe/London")

        XCTAssertEqual(days(response, now: noonUTCAfter).first?.hourlySlots.first?.localHour, 12)
    }

    func testMissingUVStaysUnknownRatherThanZero() {
        var response = openMeteoResponse(hours: 2)
        response.hourly.uvIndex = []
        let day = days(response).first

        XCTAssertNil(day?.hourlySlots.first?.uvIndex)
        XCTAssertNil(day?.uvIndexMax)
    }

    func testHoursMissingATemperatureAreSkipped() {
        var response = openMeteoResponse(hours: 3)
        response.hourly.temperature = [20, nil, 21]

        XCTAssertEqual(days(response).first?.hourlySlots.count, 2)
    }

    func testDecodesAPayloadWithMissingFields() throws {
        let json = """
        {"utc_offset_seconds":0,"hourly":{"time":[1704067200],"temperature_2m":[21.0],"weather_code":[null]}}
        """

        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(json.utf8))
        let day = days(response).first

        XCTAssertEqual(day?.hourlySlots.count, 1)
        XCTAssertEqual(day?.conditionMain, "Clouds") // a missing code falls back to overcast
        XCTAssertNil(day?.uvIndexMax)
    }

    // MARK: - WMO codes and pavement (Android WeatherHelpersTest)

    func testWMOCodesMapToAppConditionsWithDayAndNightIcons() {
        XCTAssertEqual(
            WmoWeatherCodes.condition(0, isDay: true),
            WmoWeatherCodes.Condition(main: "Clear", description: "clear sky", iconCode: "01d")
        )
        XCTAssertEqual(WmoWeatherCodes.condition(0, isDay: false).iconCode, "01n")
        XCTAssertEqual(WmoWeatherCodes.condition(95, isDay: true).main, "Thunderstorm")
        XCTAssertEqual(WmoWeatherCodes.condition(73, isDay: true).main, "Snow")
        XCTAssertEqual(WmoWeatherCodes.condition(53, isDay: true).main, "Drizzle")
        XCTAssertEqual(WmoWeatherCodes.condition(45, isDay: true).main, "Fog")
        XCTAssertEqual(WmoWeatherCodes.condition(999, isDay: true).main, "Clouds")
    }

    func testPavementMatchesAirAtNightOrWithoutSun() {
        XCTAssertEqual(PavementHeat.estimateC(airC: 20, shortwaveRadiationWm2: 900, isDay: false), 20, accuracy: 0.0001)
        XCTAssertEqual(PavementHeat.estimateC(airC: 20, shortwaveRadiationWm2: nil, isDay: true), 20, accuracy: 0.0001)
    }

    func testPavementHeatsWithSunlightUpToACap() {
        XCTAssertEqual(PavementHeat.estimateC(airC: 20, shortwaveRadiationWm2: 800, isDay: true), 48, accuracy: 0.0001)
        XCTAssertEqual(PavementHeat.estimateC(airC: 20, shortwaveRadiationWm2: 5000, isDay: true), 55, accuracy: 0.0001)
    }
}
