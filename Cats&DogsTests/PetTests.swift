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

    func testRemoteConfigThresholdsMoveTheHotAndColdMoods() {
        let thresholds = PetWeatherThresholds.validated(petHotC: 25, petColdC: 5)

        XCTAssertEqual(PetMood.forConditions(conditionMain: "Clear", iconCode: "01d", temperatureC: 26, thresholds: thresholds), .hot)
        XCTAssertEqual(PetMood.forConditions(conditionMain: "Clear", iconCode: "01d", temperatureC: 4, thresholds: thresholds), .cold)
        XCTAssertEqual(mood("Clear", "01d", 26), .sunny)
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

    func testRemoteConfigThresholdsChangeTheWalkAdvice() {
        let strict = PetWeatherThresholds.validated(maxRainChance: 5)
        let slots = [slot("3 PM", 18, rain: 10), slot("6 PM", 16, rain: 0)]

        XCTAssertEqual(WalkAdvisor.advice(currentTempC: 18, upcoming: slots)?.rating, .great)
        XCTAssertEqual(WalkAdvisor.advice(currentTempC: 18, upcoming: slots, thresholds: strict)?.bestTimeLabel, "6 PM")

        let lowerPavementLimit = PetWeatherThresholds.validated(hotPavementC: 45)
        let warmPavement = [slot("3 PM", 20, rain: 0, pavement: 48)]
        XCTAssertEqual(WalkAdvisor.advice(currentTempC: 20, upcoming: warmPavement)?.rating, .great)
        XCTAssertEqual(WalkAdvisor.advice(currentTempC: 20, upcoming: warmPavement, thresholds: lowerPavementLimit)?.rating, .pawsHot)
    }

    // MARK: - Today or tomorrow

    /// 2026-10-13 12:00 in New York (UTC-4), as a UTC epoch.
    private let noonInNewYork = 1_791_907_200
    private let newYork = TimeZone(identifier: "America/New_York")!

    func testABestTimeLaterTodayIsNotMarkedTomorrow() {
        let now = Date(timeIntervalSince1970: TimeInterval(noonInNewYork))
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [slot("12 PM", 18, rain: 90, epoch: noonInNewYork), slot("5 PM", 18, rain: 0, epoch: noonInNewYork + 5 * 3600)],
            now: now,
            timeZone: newYork
        )

        XCTAssertEqual(advice?.bestTimeLabel, "5 PM")
        XCTAssertEqual(advice?.bestTimeIsTomorrow, false)
    }

    func testABestTimeTomorrowMorningIsMarkedTomorrow() {
        let now = Date(timeIntervalSince1970: TimeInterval(noonInNewYork))
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [slot("12 PM", 18, rain: 90, epoch: noonInNewYork), slot("7 AM", 18, rain: 0, epoch: noonInNewYork + 19 * 3600)],
            now: now,
            timeZone: newYork
        )

        XCTAssertEqual(advice?.bestTimeLabel, "7 AM")
        XCTAssertEqual(advice?.bestTimeIsTomorrow, true)
    }

    func testTodayAndTomorrowAreTheCitysNotTheDevices() {
        // 11 PM in Tokyo is 10 AM in New York and 2 PM UTC; 1 AM Tokyo is still the same day in both
        // of those, but tomorrow in Tokyo.
        let elevenPMTokyo = noonInNewYork - 2 * 3600
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [
                slot("11 PM", 18, rain: 90, hour: 12, epoch: elevenPMTokyo),
                slot("1 AM", 18, rain: 0, hour: 12, epoch: elevenPMTokyo + 2 * 3600),
            ],
            now: Date(timeIntervalSince1970: TimeInterval(elevenPMTokyo)),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )

        XCTAssertEqual(advice?.bestTimeIsTomorrow, true)
    }

    func testSlotsMoreThanADayAheadAreIgnored() {
        // Three-hourly slots: only one dry slot, 27 hours out.
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [
                slot("12 PM", 18, rain: 90, epoch: noonInNewYork),
                slot("3 PM", 18, rain: 90, epoch: noonInNewYork + 3 * 3600),
                slot("3 PM", 18, rain: 0, epoch: noonInNewYork + 27 * 3600),
            ],
            now: Date(timeIntervalSince1970: TimeInterval(noonInNewYork)),
            timeZone: newYork
        )

        XCTAssertEqual(advice?.rating, .poor)
        XCTAssertNil(advice?.bestTimeLabel)
    }

    func testASlotWithoutATimestampIsNeverMarkedTomorrow() {
        let advice = WalkAdvisor.advice(
            currentTempC: 18,
            upcoming: [slot("12 PM", 18, rain: 90), slot("7 AM", 18, rain: 0)],
            now: Date(timeIntervalSince1970: TimeInterval(noonInNewYork)),
            timeZone: newYork
        )

        XCTAssertEqual(advice?.bestTimeIsTomorrow, false)
    }

    // MARK: - Dropping past slots

    func testPastSlotsAreDroppedAndTheOneInProgressIsKept() {
        let slots = (0 ..< 5).map { slot("\($0)", 18, rain: 0, hour: 12, epoch: noonInNewYork + ($0 - 2) * 3600) }

        let upcoming = slots.upcoming(from: Date(timeIntervalSince1970: TimeInterval(noonInNewYork + 1800)))

        XCTAssertEqual(upcoming.map(\.timeLabel), ["2", "3", "4"])
    }

    func testThreeHourlySlotsKeepTheBlockInProgress() {
        let slots = (0 ..< 4).map { slot("\($0)", 18, rain: 0, hour: 12, epoch: noonInNewYork + $0 * 3 * 3600) }

        let upcoming = slots.upcoming(from: Date(timeIntervalSince1970: TimeInterval(noonInNewYork + 4 * 3600)))

        XCTAssertEqual(upcoming.map(\.timeLabel), ["1", "2", "3"])
    }

    func testAForecastThatHasNotStartedYetIsKeptWhole() {
        let slots = (0 ..< 3).map { slot("\($0)", 18, rain: 0, hour: 12, epoch: noonInNewYork + $0 * 3600) }

        XCTAssertEqual(slots.upcoming(from: Date(timeIntervalSince1970: TimeInterval(noonInNewYork - 600))), slots)
    }

    func testSlotsWithoutTimestampsAreKept() {
        let slots = [slot("3 PM", 18, rain: 0), slot("6 PM", 18, rain: 0)]

        XCTAssertEqual(slots.upcoming(from: Date()), slots)
    }

    func testASlotBeforeSunriseIsNotAWalkTimeEvenInsideTheWalkingHours() {
        // 7 AM is within 7 AM...8 PM, but on a winter morning it can still be dark (a night icon).
        let advice = WalkAdvisor.advice(currentTempC: 12, upcoming: [slot("7 AM", 12, rain: 5, icon: "03n"), slot("8 AM", 12, rain: 5, icon: "03d")])
        XCTAssertEqual(advice, WalkAdvice(rating: .okay, bestTimeLabel: "8 AM"))
    }

    func testRainingNowMeansNowIsNotTheWalkTimeEvenIfTheForecastHourLooksDry() {
        let slots = [slot("3 PM", 18, rain: 10), slot("4 PM", 18, rain: 10)]
        XCTAssertEqual(WalkAdvisor.advice(currentTempC: 18, upcoming: slots), WalkAdvice(rating: .great, bestTimeLabel: nil))
        XCTAssertEqual(
            WalkAdvisor.advice(currentTempC: 18, upcoming: slots, precipitatingNow: true),
            WalkAdvice(rating: .okay, bestTimeLabel: "4 PM")
        )
    }

    func testRainingNowWithNoDryWindowLaterIsPoor() {
        let advice = WalkAdvisor.advice(currentTempC: 18, upcoming: [slot("3 PM", 18, rain: 10), slot("4 PM", 18, rain: 90)], precipitatingNow: true)
        XCTAssertEqual(advice, WalkAdvice(rating: .poor, bestTimeLabel: nil))
    }

    func testPrecipitationIsReadFromTheCondition() {
        for main in ["Rain", "drizzle", "Snow", "Thunderstorm"] {
            XCTAssertTrue(WalkAdvisor.isPrecipitating(conditionMain: main), main)
        }
        for main in ["Clear", "Clouds", "Mist", "Fog"] {
            XCTAssertFalse(WalkAdvisor.isPrecipitating(conditionMain: main), main)
        }
    }

    private func slot(
        _ label: String,
        _ temp: Double,
        rain: Int,
        units: WeatherUnits = .metric,
        pavement: Double? = nil,
        hour: Int? = nil,
        epoch: Int? = nil,
        icon: String = "01d"
    ) -> HourlySlot {
        HourlySlot(
            timeLabel: label,
            iconCode: icon,
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
            localHour: hour ?? Self.hourOf(label),
            epochSeconds: epoch
        )
    }

    /// Test-only: reads the hour from a "3 PM"-style label.
    private static func hourOf(_ label: String) -> Int? {
        let parts = label.split(separator: " ")
        guard parts.count == 2, let h = Int(parts[0]) else { return nil }
        return h % 12 + (parts[1] == "PM" ? 12 : 0)
    }
}
