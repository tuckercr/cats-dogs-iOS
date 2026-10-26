import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherIconViewTests: XCTestCase {
    func testClearFewCloudsAndRainHaveNightVersions() {
        XCTAssertEqual(WeatherIconView.assetName(for: "01d"), "wx_01d")
        XCTAssertEqual(WeatherIconView.assetName(for: "01n"), "wx_01n")
        XCTAssertEqual(WeatherIconView.assetName(for: "02n"), "wx_02n")
        XCTAssertEqual(WeatherIconView.assetName(for: "10n"), "wx_10n")
    }

    func testOtherConditionsShareOneIconByDayAndNight() {
        for code in ["03", "04", "09", "11", "13", "50"] {
            XCTAssertEqual(WeatherIconView.assetName(for: "\(code)d"), WeatherIconView.assetName(for: "\(code)n"), code)
        }
    }

    func testAnUnknownCodeFallsBackToACloud() {
        XCTAssertEqual(WeatherIconView.assetName(for: ""), "wx_03d")
        XCTAssertEqual(WeatherIconView.assetName(for: "99d"), "wx_03d")
    }

    func testEveryAssetExists() {
        for code in ["01d", "01n", "02d", "02n", "03d", "04d", "09d", "10d", "10n", "11d", "13d", "50d"] {
            XCTAssertNotNil(UIImage(named: WeatherIconView.assetName(for: code)), code)
        }
    }
}
