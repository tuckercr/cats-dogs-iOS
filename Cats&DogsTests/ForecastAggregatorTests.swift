import XCTest
@testable import Cats_Dogs

@MainActor
final class ForecastAggregatorTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testPrecipitationChanceIsPerSlotPercentHourlyAndDailyMax() {
        let dayStart = 1_704_067_200 // 2024-01-01T00:00:00Z
        let slots = [
            slot(epochSeconds: dayStart + 3600, pop: 0.1),
            slot(epochSeconds: dayStart + 12 * 3600, pop: 0.85),
            slot(epochSeconds: dayStart + 18 * 3600, pop: 0.4),
        ]

        let day = ForecastAggregator.aggregate(slots: slots, timeZone: utc, units: .metric).first

        // Daily chance is the max across the day's slots; each hour carries its own percentage.
        XCTAssertEqual(day?.precipitationChance, 85)
        XCTAssertEqual(day?.hourlySlots.map(\.precipitationChance), [10, 85, 40])
    }

    func testHourlySlotsCarryTheirLocalHourAndTimestamp() {
        let dayStart = 1_704_067_200 // 2024-01-01T00:00:00Z
        let denver = TimeZone(secondsFromGMT: -7 * 3600)!
        let slots = [slot(epochSeconds: dayStart + 18 * 3600)] // 18:00 UTC = 11:00 in Denver

        let hour = ForecastAggregator.aggregate(slots: slots, timeZone: denver, units: .metric).first?.hourlySlots.first

        XCTAssertEqual(hour?.localHour, 11)
        XCTAssertEqual(hour?.epochSeconds, dayStart + 18 * 3600)
    }

    func testUVIndexMaxIsNilWhenTheSourceHasNoUV() {
        let dayStart = 1_704_067_200
        let withUV = [slot(epochSeconds: dayStart + 3600, uvIndex: 2), slot(epochSeconds: dayStart + 7200, uvIndex: 6.5)]

        XCTAssertEqual(ForecastAggregator.aggregate(slots: withUV, timeZone: utc, units: .metric).first?.uvIndexMax, 6.5)
        XCTAssertNil(ForecastAggregator.aggregate(slots: [slot(epochSeconds: dayStart)], timeZone: utc, units: .metric).first?.uvIndexMax)
    }

    func testAggregatePicksNoonSlotPerDay() {
        let dayStart = 1_704_067_200 // 2024-01-01T00:00:00Z
        let noon = dayStart + 12 * 3600
        let slots = [
            ForecastAggregator.Slot(
                epochSeconds: dayStart + 3600,
                temperature: 1.0,
                feelsLike: 0.0,
                conditionMain: "Morning",
                description: "morning",
                iconCode: "01d"
            ),
            ForecastAggregator.Slot(
                epochSeconds: noon,
                temperature: 10.0,
                feelsLike: 9.0,
                conditionMain: "Noon",
                description: "noon",
                iconCode: "02d"
            ),
            ForecastAggregator.Slot(
                epochSeconds: dayStart + 18 * 3600,
                temperature: 3.0,
                feelsLike: 2.0,
                conditionMain: "Evening",
                description: "evening",
                iconCode: "03d"
            ),
        ]

        let days = ForecastAggregator.aggregate(slots: slots, timeZone: utc, units: .metric)

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days.first?.conditionMain, "Noon")
        XCTAssertEqual(days.first?.temperature ?? 0, 10.0, accuracy: 0.0001)
    }

    func testAggregateSplitsMultipleCalendarDays() {
        let day1 = 1_704_067_200 // 2024-01-01T00:00:00Z
        let day2 = day1 + 86_400 // 2024-01-02T00:00:00Z
        let slots = [
            ForecastAggregator.Slot(
                epochSeconds: day1,
                temperature: 1.0,
                feelsLike: 1.0,
                conditionMain: "A",
                description: "a",
                iconCode: "01d"
            ),
            ForecastAggregator.Slot(
                epochSeconds: day2,
                temperature: 2.0,
                feelsLike: 2.0,
                conditionMain: "B",
                description: "b",
                iconCode: "02d"
            ),
        ]

        let days = ForecastAggregator.aggregate(slots: slots, timeZone: utc, units: .metric)

        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days.last?.conditionMain, "B")
    }

    private func slot(epochSeconds: Int, pop: Double = 0, uvIndex: Double? = nil) -> ForecastAggregator.Slot {
        ForecastAggregator.Slot(
            epochSeconds: epochSeconds,
            temperature: 10,
            feelsLike: 9,
            conditionMain: "Clear",
            description: "clear sky",
            iconCode: "01d",
            pop: pop,
            uvIndex: uvIndex
        )
    }
}
