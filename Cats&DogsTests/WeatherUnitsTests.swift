import XCTest
@testable import Cats_Dogs

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
}
