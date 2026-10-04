import XCTest
@testable import Cats_Dogs

@MainActor
final class OpenWeatherParsingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testParsesUTCOffsetFromCurrentWeatherAndForecastPayloads() throws {
        let current = """
        {
          "name": "Denver",
          "weather": [ { "main": "Clear", "description": "clear sky", "icon": "01d" } ],
          "main": { "temp": 10.0, "feels_like": 9.0, "humidity": 40 },
          "wind": { "speed": 1.0 },
          "timezone": -21600
        }
        """
        let forecast = """
        { "list": [], "city": { "name": "London", "timezone": 3600 } }
        """

        // Mountain Daylight Time is UTC-6h.
        XCTAssertEqual(try decoder.decode(CurrentWeatherResponse.self, from: Data(current.utf8)).timezone, -21600)
        XCTAssertEqual(try decoder.decode(ForecastResponse.self, from: Data(forecast.utf8)).city?.timezone, 3600)
    }

    func testParsesPrecipitationProbabilityAndDefaultsWhenAbsent() throws {
        let json = """
        { "list": [
          { "dt": 1, "main": { "temp": 1, "feels_like": 1, "humidity": 1 },
            "weather": [ { "main": "Rain", "description": "rain", "icon": "10d" } ],
            "wind": { "speed": 1 }, "pop": 0.62 },
          { "dt": 2, "main": { "temp": 1, "feels_like": 1, "humidity": 1 },
            "weather": [ { "main": "Clear", "description": "clear", "icon": "01d" } ],
            "wind": { "speed": 1 } }
        ] }
        """

        let parsed = try decoder.decode(ForecastResponse.self, from: Data(json.utf8))

        XCTAssertEqual(parsed.list[0].pop, 0.62)
        XCTAssertNil(parsed.list[1].pop)
    }

    func testParsesCurrentWeatherPayload() throws {
        let json = """
        {
          "name": "Austin",
          "weather": [
            { "main": "Clear", "description": "clear sky", "icon": "01n" }
          ],
          "main": { "temp": 21.3, "feels_like": 20.1, "humidity": 55 },
          "wind": { "speed": 4.2 }
        }
        """

        let parsed = try decoder.decode(CurrentWeatherResponse.self, from: Data(json.utf8))

        XCTAssertEqual(parsed.name, "Austin")
        XCTAssertEqual(parsed.weather.first?.main, "Clear")
        XCTAssertEqual(parsed.main.temp, 21.3, accuracy: 0.0001)
        XCTAssertEqual(parsed.main.feelsLike, 20.1, accuracy: 0.0001)
        XCTAssertEqual(parsed.main.humidity, 55)
        XCTAssertEqual(parsed.wind.speed, 4.2, accuracy: 0.0001)
        XCTAssertEqual(parsed.main.tempMin, 0, accuracy: 0.0001)
        XCTAssertNil(parsed.visibility)
    }

    func testParsesForecastPayloadList() throws {
        let json = """
        {
          "list": [
            {
              "dt": 1700000000,
              "main": { "temp": 5.0, "feels_like": 4.0, "humidity": 80 },
              "weather": [ { "main": "Rain", "description": "light rain", "icon": "10d" } ],
              "wind": { "speed": 2.0 }
            }
          ]
        }
        """

        let parsed = try decoder.decode(ForecastResponse.self, from: Data(json.utf8))

        XCTAssertEqual(parsed.list.count, 1)
        XCTAssertEqual(parsed.list.first?.dt, 1_700_000_000)
        XCTAssertEqual(parsed.list.first?.weather.first?.main, "Rain")
    }
}
