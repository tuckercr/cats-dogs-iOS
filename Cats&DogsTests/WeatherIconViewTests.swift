import XCTest
@testable import Cats_Dogs

@MainActor
final class WeatherIconViewTests: XCTestCase {
    func testNightIconsShowTheMoonsPhase() {
        XCTAssertEqual(WeatherIconView.assetName(for: "01d", phase: .new), "wx_01d")
        XCTAssertEqual(WeatherIconView.assetName(for: "01n", phase: .full), "wx_01n_full")
        XCTAssertEqual(WeatherIconView.assetName(for: "01n", phase: .new), "wx_01n_new")
        XCTAssertEqual(WeatherIconView.assetName(for: "02n", phase: .firstQuarter), "wx_02n_first_quarter")
        XCTAssertEqual(WeatherIconView.assetName(for: "10n", phase: .waningCrescent), "wx_10n_waning_crescent")
    }

    func testTheSouthernHemispheresMoonIsLitFromTheOtherSideExceptNewAndFull() {
        XCTAssertEqual(WeatherIconView.assetName(for: "01n", phase: .waxingCrescent, southernHemisphere: true), "wx_01n_waxing_crescent_s")
        XCTAssertEqual(WeatherIconView.assetName(for: "10n", phase: .lastQuarter, southernHemisphere: true), "wx_10n_last_quarter_s")
        XCTAssertEqual(WeatherIconView.assetName(for: "01n", phase: .full, southernHemisphere: true), "wx_01n_full")
        XCTAssertEqual(WeatherIconView.assetName(for: "02n", phase: .new, southernHemisphere: true), "wx_02n_new")
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
        for code in ["01d", "02d", "03d", "04d", "09d", "10d", "11d", "13d", "50d"] {
            XCTAssertNotNil(UIImage(named: WeatherIconView.assetName(for: code)), code)
        }
        for code in ["01n", "02n", "10n"] {
            for phase in MoonPhase.allCases {
                for south in [false, true] {
                    let name = WeatherIconView.assetName(for: code, phase: phase, southernHemisphere: south)
                    XCTAssertNotNil(UIImage(named: name), name)
                }
            }
        }
    }
}

final class MoonPhaseTests: XCTestCase {
    private func phase(_ iso: String) -> MoonPhase {
        MoonPhase(at: ISO8601DateFormatter().date(from: iso)!)
    }

    func testMatchesThePublishedPhasesOfJanuary2024() {
        XCTAssertEqual(phase("2024-01-04T03:30:00Z"), .lastQuarter)
        XCTAssertEqual(phase("2024-01-11T11:57:00Z"), .new)
        XCTAssertEqual(phase("2024-01-18T03:53:00Z"), .firstQuarter)
        XCTAssertEqual(phase("2024-01-25T17:54:00Z"), .full)
    }

    func testStepsThroughThePhasesInOrderAcrossACycle() {
        let newMoon = ISO8601DateFormatter().date(from: "2024-01-11T11:57:00Z")!
        let eighth = 29.530588853 * 86_400 / 8
        for phase in MoonPhase.allCases {
            XCTAssertEqual(MoonPhase(at: newMoon.addingTimeInterval(Double(phase.rawValue) * eighth)), phase)
        }
    }

    func testDatesBeforeTheReferenceNewMoonStillWork() {
        XCTAssertEqual(phase("1999-12-22T17:31:00Z"), .full)
    }
}
