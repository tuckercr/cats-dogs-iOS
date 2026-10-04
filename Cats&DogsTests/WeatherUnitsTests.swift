import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherUnitsTests: XCTestCase {
    func testUSAndTerritoriesUseImperial() {
        XCTAssertEqual(WeatherUnits.fromRegionCode("US"), .imperial)
        XCTAssertEqual(WeatherUnits.fromRegionCode("PR"), .imperial)
        XCTAssertEqual(WeatherUnits.fromRegionCode("GU"), .imperial)
    }

    func testUKAndOthersUseMetric() {
        XCTAssertEqual(WeatherUnits.fromRegionCode("GB"), .metric)
        XCTAssertEqual(WeatherUnits.fromRegionCode("CA"), .metric)
        XCTAssertEqual(WeatherUnits.fromRegionCode("DE"), .metric)
    }

    func testConvertsToAndFromCelsius() {
        XCTAssertEqual(WeatherUnits.imperial.toCelsius(32), 0, accuracy: 0.001)
        XCTAssertEqual(WeatherUnits.imperial.toCelsius(86), 30, accuracy: 0.001)
        XCTAssertEqual(WeatherUnits.metric.toCelsius(21.5), 21.5, accuracy: 0.001)
        XCTAssertEqual(WeatherUnits.imperial.fromCelsius(100), 212, accuracy: 0.001)
        XCTAssertEqual(WeatherUnits.metric.fromCelsius(-4), -4, accuracy: 0.001)
    }
}
