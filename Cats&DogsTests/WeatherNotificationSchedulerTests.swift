import XCTest
@testable import Cats_Dogs

final class WeatherNotificationSchedulerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: minute))!
    }

    func testOnlyTheNextNotificationAtEachTimeCarriesTheWeather() {
        // 10:30 AM on the 1st: 9 AM has passed, so its next one is tomorrow.
        let planned = WeatherNotificationScheduler.plannedNotifications(after: date(1, 10, 30), calendar: calendar)
        let next = planned.filter(\.isNext)

        XCTAssertEqual(next.map(\.date), [date(1, 13), date(1, 19), date(2, 9)])
        XCTAssertEqual(next.map(\.identifier), ["weather_daily_13", "weather_daily_19", "weather_daily_9"])
    }

    func testAWeekIsQueuedAtEachTimeWithoutRepeating() {
        let planned = WeatherNotificationScheduler.plannedNotifications(after: date(1, 10, 30), calendar: calendar)

        XCTAssertEqual(planned.count, 21)
        XCTAssertEqual(Set(planned.map(\.identifier)).count, 21, "Identifiers must be unique")
        XCTAssertEqual(planned.first?.date, date(1, 13))
        XCTAssertEqual(planned.last?.date, date(8, 9))
        XCTAssertEqual(planned.map(\.date), planned.map(\.date).sorted())
    }

    func testANotificationTimeThatIsNowIsNotRescheduledForNow() {
        let planned = WeatherNotificationScheduler.plannedNotifications(after: date(1, 9), calendar: calendar)

        XCTAssertEqual(planned.first { $0.identifier == "weather_daily_9" }?.date, date(2, 9))
    }

    func testTheQueueSurvivesADaylightSavingChange() {
        // US clocks go forward at 2 AM on March 8, 2026.
        let planned = WeatherNotificationScheduler.plannedNotifications(
            after: calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 20))!,
            calendar: calendar
        )

        XCTAssertTrue(planned.allSatisfy { [9, 13, 19].contains(calendar.component(.hour, from: $0.date)) })
    }
}
