import XCTest
@testable import Cats_Dogs

@MainActor
final class NextRainTests: XCTestCase {
    private let start = 1_704_067_200 // a quarter-hour boundary
    private var startDate: Date { Date(timeIntervalSince1970: TimeInterval(start)) }

    private func quarters(_ mm: [Double], snow: Bool = false) -> [QuarterHour] {
        mm.enumerated().map { i, amount in
            QuarterHour(epochSeconds: start + i * 900, precipitationMm: amount, snowfallCm: snow && amount > 0 ? 1 : 0)
        }
    }

    func testDryForTheNext2HoursSaysNothing() {
        XCTAssertNil(NextRain.from(quarters([0, 0, 0, 0, 0, 0, 0, 0]), now: startDate))
    }

    func testTracesUnder0Point1MmDontCount() {
        XCTAssertNil(NextRain.from(quarters([0, 0.05, 0, 0, 0, 0, 0, 0]), now: startDate))
    }

    func testDryNowAndWetLaterIsWhenItStarts() {
        XCTAssertEqual(
            NextRain.from(quarters([0, 0, 0, 0.4, 1, 0.2, 0, 0]), now: startDate),
            .starting(epochSeconds: start + 3 * 900, snow: false)
        )
    }

    func testRainBeyond2HoursIsntMentioned() {
        XCTAssertNil(NextRain.from(quarters([0, 0, 0, 0, 0, 0, 0, 0, 1]), now: startDate))
    }

    func testWetNowStopsAtTheFirst30DryMinutesNotAShortGap() {
        XCTAssertEqual(
            NextRain.from(quarters([0.5, 0.5, 0, 0.3, 0, 0, 0, 0]), now: startDate),
            .stopping(epochSeconds: start + 4 * 900, snow: false)
        )
    }

    func testWetNowAndDryOnlyAtTheLastQuarterStillStops() {
        XCTAssertEqual(
            NextRain.from(quarters([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0]), now: startDate),
            .stopping(epochSeconds: start + 7 * 900, snow: false)
        )
    }

    func testWetThroughoutKeepsOn() {
        XCTAssertEqual(NextRain.from(quarters([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]), now: startDate), .continuing(snow: false))
    }

    func testSnowIsNamedAsSnow() {
        let next = NextRain.from(quarters([0, 0.4, 0.4, 0.4, 0, 0, 0, 0], snow: true), now: startDate)
        XCTAssertEqual(next, .starting(epochSeconds: start + 900, snow: true))
        XCTAssertTrue(next?.line(timeZone: TimeZone(identifier: "UTC")!).hasPrefix("Snow starting around 12:15") == true)
    }

    func testItReadsFromTheQuarterInProgress() {
        // 20 minutes in: the first quarter is over, so the rain in the second is "now".
        XCTAssertEqual(
            NextRain.from(quarters([0, 0.5, 0.5, 0, 0, 0, 0, 0]), now: startDate.addingTimeInterval(20 * 60)),
            .stopping(epochSeconds: start + 3 * 900, snow: false)
        )
    }

    func testAForecastWithUnderAnHourLeftSaysNothing() {
        XCTAssertNil(NextRain.from(quarters([0, 0, 0.4]), now: startDate))
    }

    func testFifteenMinuteAmountsBecomeQuartersStarting15MinutesBeforeTheirTime() {
        let response = OpenMeteoResponse(
            hourly: openMeteoResponse(hours: 3).hourly,
            minutely15: OpenMeteoMinutely15DTO(
                time: [start + 900, start + 1800, start + 2700],
                precipitation: [0, 0.4, nil],
                snowfall: [0, 0.2, 0]
            )
        )
        let days = OpenMeteoForecast.dayForecasts(from: response, units: .metric, now: startDate)

        XCTAssertEqual(
            days.first?.quarterHours,
            [QuarterHour(epochSeconds: start, precipitationMm: 0, snowfallCm: 0), QuarterHour(epochSeconds: start + 900, precipitationMm: 0.4, snowfallCm: 0.2)]
        )
    }
}
