import XCTest
@testable import Cats_Dogs

final class OpenWeatherParsingTests: XCTestCase {
    private let decoder = JSONDecoder()

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
