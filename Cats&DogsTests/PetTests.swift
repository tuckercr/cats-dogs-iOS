import XCTest
@testable import Cats_Dogs

@MainActor
final class PetMoodTests: XCTestCase {
    private func mood(_ main: String, _ icon: String, _ tempC: Double) -> PetMood {
        PetMood.forConditions(conditionMain: main, iconCode: icon, temperatureC: tempC)
    }

    func testPrecipitationAndStormsMapToTheirMoodsRegardlessOfTemperature() {
        XCTAssertEqual(mood("Thunderstorm", "11d", 35), .storm)
        XCTAssertEqual(mood("Snow", "13d", -5), .snow)
        XCTAssertEqual(mood("Rain", "10d", 32), .rain)
        XCTAssertEqual(mood("Drizzle", "09n", 12), .rain)
    }

    func testTemperatureExtremesWinOverSkyAndTimeOfDay() {
        XCTAssertEqual(mood("Clear", "01d", 30), .hot)
        XCTAssertEqual(mood("Clouds", "04n", 0), .cold)
    }

    func testNightIconMeansNightOtherwiseClearIsSunnyAndAnythingElseIsCloudy() {
        XCTAssertEqual(mood("Clear", "01n", 15), .night)
        XCTAssertEqual(mood("Clear", "01d", 20), .sunny)
        XCTAssertEqual(mood("Clouds", "03d", 20), .cloudy)
        XCTAssertEqual(mood("Mist", "50d", 12), .cloudy)
    }

    func testCaptionIsStableForADayAndEveryMoodHasOne() {
        let date = Date(timeIntervalSince1970: TimeInterval(fixtureDayStart))
        for mood in PetMood.allCases {
            XCTAssertFalse(mood.captions.isEmpty)
            XCTAssertEqual(mood.caption(on: date), mood.caption(on: date.addingTimeInterval(3600)))
        }
    }
}

@MainActor
final class WalkAdvisorTests: XCTestCase {
    func testGreatWhenTheNextSlotIsDryAndComfortable() {
        let advice = WalkAdvisor.advice(currentTempC: 18, upcoming: [slot("3 PM", 18, rain: 10), slot("6 PM", 16, rain: 80)])
        XCTAssertEqual(advice, WalkAdvice(rating: .great, bestTimeLabel: nil))
    }

    func testOkayWithTheFirstGoodWindowWhenItIsWetNow() {
        let advice = WalkAdvisor.advice(currentTempC: 12, upcoming: [slot("3 PM", 12, rain: 90), slot("6 PM", 13, rain: 10)])
        XCTAssertEqual(advice, WalkAdvice(rating: .okay, bestTimeLabel: "6 PM"))
    }

    func testPoorWhenThereIsNoGoodWindowInTheLookahead() {
        let advice = WalkAdvisor.advice(currentTempC: 12, upcoming: (0..<8).map { slot("\($0)h", 12, rain: 90, hour: 12) })
        XCTAssertEqual(advice, WalkAdvice(rating: .poor, bestTimeLabel: nil))
    }

    func testPawsHotAboveTheHeatThresholdPointingAtTheFirstCoolerSlot() {
        let advice = WalkAdvisor.advice(currentTempC: 33, upcoming: [slot("3 PM", 33, rain: 0), slot("7 PM", 24, rain: 0)])
        XCTAssertEqual(advice, WalkAdvice(rating: .pawsHot, bestTimeLabel: "7 PM"))
    }

    func testTooColdAtOrBelowFreezing() {
        XCTAssertEqual(WalkAdvisor.advice(currentTempC: -3, upcoming: [slot("3 PM", -3, rain: 0)])?.rating, .tooCold)
    }

    func testImperialSlotsAreComparedInCelsius() {
        // 64F is about 18C: comfortable.
        let advice = WalkAdvisor.advice(currentTempC: 18, upcoming: [slot("3 PM", 64, rain: 0, units: .imperial)])
        XCTAssertEqual(advice?.rating, .great)
    }

    func testNightSlotsAreSkippedInFavourOfTheFirstDaytimeWindow() {
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [slot("2 AM", 18, rain: 0), slot("5 AM", 17, rain: 0), slot("8 AM", 16, rain: 0)]
        )
        XCTAssertEqual(advice, WalkAdvice(rating: .okay, bestTimeLabel: "8 AM"))
    }

    func testNoSlotsMeansNoAdvice() {
        XCTAssertNil(WalkAdvisor.advice(currentTempC: 18, upcoming: []))
    }

    func testNightIsJudgedByLocalHourNotTheLabelText() {
        // A label in a locale that can't be parsed; the hour still rules it out.
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [slot("午前2時", 18, rain: 0, hour: 2), slot("午前8時", 16, rain: 0, hour: 8)]
        )
        XCTAssertEqual(advice?.bestTimeLabel, "午前8時")
    }

    func testHotPavementOnAMildDayMeansPawsHotPointingAtTheFirstCoolerHour() {
        let advice = WalkAdvisor.advice(
            currentTempC: 24,
            upcoming: [slot("1 PM", 24, rain: 0, pavement: 58), slot("6 PM", 22, rain: 0, pavement: 30)]
        )
        XCTAssertEqual(advice, WalkAdvice(rating: .pawsHot, bestTimeLabel: "6 PM", pavementNow: 58))
    }

    func testImperialPavementIsComparedInCelsius() {
        // 120F is about 49C: under the 52C paw limit, so a warm afternoon is still walkable.
        let advice = WalkAdvisor.advice(
            currentTempC: 26,
            upcoming: [slot("2 PM", 79, rain: 0, units: .imperial, pavement: 120)]
        )
        XCTAssertEqual(advice?.rating, .great)
    }

    private func slot(
        _ label: String,
        _ temp: Double,
        rain: Int,
        units: WeatherUnits = .metric,
        pavement: Double? = nil,
        hour: Int? = nil
    ) -> HourlySlot {
        HourlySlot(
            timeLabel: label,
            iconCode: "01d",
            description: "clear",
            temperature: temp,
            feelsLike: temp,
            windSpeed: 1,
            windDeg: 0,
            humidity: 50,
            pressure: 1013,
            units: units,
            precipitationChance: rain,
            pavementTemperature: pavement,
            localHour: hour ?? Self.hourOf(label)
        )
    }

    /// Test-only: reads the hour from a "3 PM"-style label.
    private static func hourOf(_ label: String) -> Int? {
        let parts = label.split(separator: " ")
        guard parts.count == 2, let h = Int(parts[0]) else { return nil }
        return h % 12 + (parts[1] == "PM" ? 12 : 0)
    }
}
