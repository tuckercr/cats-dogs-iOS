import XCTest
@testable import Cats_Dogs

final class WeatherRepositoryTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testFetchCurrentWeatherWithCoordinatesSendsCoordinatesAndPreservesLocationLabel() async {
        let api = FakeOpenWeatherAPI()
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(
            units: .imperial,
            locationLabel: "Austin, TX, US",
            cityQuery: "Austin",
            latitude: 30.2672,
            longitude: -97.7431
        )

        let weather = try! result.get()
        XCTAssertEqual(weather.cityName, "Austin, TX, US")
        XCTAssertEqual(weather.description, "Clear sky")
        XCTAssertEqual(weather.units, .imperial)
        XCTAssertNil(api.lastCurrentCityQuery)
        XCTAssertEqual(api.lastCurrentLatitude ?? 0, 30.2672, accuracy: 0.0001)
        XCTAssertEqual(api.lastCurrentLongitude ?? 0, -97.7431, accuracy: 0.0001)
        XCTAssertEqual(api.lastCurrentUnits, .imperial)
        XCTAssertEqual(api.currentWeatherCallCount, 1)
    }

    func testFetchCurrentWeatherTrimsCityQueryWhenCoordinatesAreAbsent() async {
        let api = FakeOpenWeatherAPI()
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(
            units: .metric,
            cityQuery: "  Denver  "
        )

        let weather = try! result.get()
        XCTAssertEqual(weather.cityName, "OpenWeather City")
        XCTAssertEqual(api.lastCurrentCityQuery, "Denver")
        XCTAssertNil(api.lastCurrentLatitude)
        XCTAssertNil(api.lastCurrentLongitude)
        XCTAssertEqual(api.lastCurrentUnits, .metric)
    }

    func testFetchCurrentWeatherWithBlankCityQueryFailsBeforeCallingAPI() async {
        let api = FakeOpenWeatherAPI()
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(units: .metric, cityQuery: "   ")

        guard case .failure(let error as OpenWeatherClientError) = result else {
            return XCTFail("Expected emptyQuery failure")
        }
        XCTAssertEqual(error, .emptyQuery)
        XCTAssertEqual(api.currentWeatherCallCount, 0)
    }

    func testFetchForecastWithMissingApiKeyFailsBeforeCallingAPI() async {
        let api = FakeOpenWeatherAPI()
        let repository = WeatherRepository(
            client: OpenWeatherClient(apiKey: "   "),
            timeZone: utc
        )

        let result = await repository.fetchForecast(units: .metric, cityQuery: "Austin")

        guard case .failure(let error as OpenWeatherClientError) = result else {
            return XCTFail("Expected missingApiKey failure")
        }
        XCTAssertEqual(error, .missingApiKey)
        XCTAssertEqual(api.forecastCallCount, 0)
    }

    func testFetchForecastMapsForecastSlotsThroughAggregator() async {
        let dayStart = 1_704_067_200
        let api = FakeOpenWeatherAPI(
            forecastResponse: ForecastResponse(
                list: [
                    forecastItem(epochSeconds: dayStart + 3600, temperature: 1.0, main: "Morning"),
                    forecastItem(epochSeconds: dayStart + 12 * 3600, temperature: 10.0, main: "Noon"),
                ]
            )
        )
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchForecast(
            units: .metric,
            latitude: 30.2672,
            longitude: -97.7431
        )

        let forecast = try! result.get()
        XCTAssertEqual(forecast.count, 1)
        XCTAssertEqual(forecast.first?.conditionMain, "Noon")
        XCTAssertEqual(forecast.first?.description, "Noon description")
        XCTAssertEqual(forecast.first?.temperature ?? 0, 10.0, accuracy: 0.0001)
        XCTAssertEqual(forecast.first?.units, .metric)
        XCTAssertNil(api.lastForecastCityQuery)
        XCTAssertEqual(api.lastForecastLatitude ?? 0, 30.2672, accuracy: 0.0001)
        XCTAssertEqual(api.lastForecastLongitude ?? 0, -97.7431, accuracy: 0.0001)
    }

    func testFetchCurrentWeatherMapsNetworkFailures() async {
        let api = FakeOpenWeatherAPI(currentError: OpenWeatherClientError.network)
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(units: .metric, cityQuery: "Austin")

        guard case .failure(let error as OpenWeatherClientError) = result else {
            return XCTFail("Expected network failure")
        }
        XCTAssertEqual(error, .network)
    }

    func testFetchCurrentWeatherMapsOpenWeatherErrorBodyMessage() async {
        let api = FakeOpenWeatherAPI(
            currentError: OpenWeatherClientError.http(statusCode: 404, message: "city not found")
        )
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(units: .metric, cityQuery: "Missing City")

        guard case .failure(let error as OpenWeatherClientError) = result else {
            return XCTFail("Expected http failure")
        }
        if case .http(_, let message) = error {
            XCTAssertEqual(message, "city not found")
        } else {
            XCTFail("Expected http case")
        }
    }

    func testFetchCurrentWeatherMapsMissingWeatherEntryToInvalidPayload() async {
        let api = FakeOpenWeatherAPI(
            currentResponse: CurrentWeatherResponse(
                name: "Broken City",
                weather: [],
                main: MainDTO(temp: 21.0, feelsLike: 20.0, humidity: 55),
                wind: WindDTO(speed: 4.2)
            )
        )
        let repository = WeatherRepository(client: api, timeZone: utc)

        let result = await repository.fetchCurrentWeather(units: .metric, cityQuery: "Broken City")

        guard case .failure(let error as OpenWeatherClientError) = result else {
            return XCTFail("Expected invalidPayload failure")
        }
        XCTAssertEqual(error, .invalidPayload)
    }
}

private final class FakeOpenWeatherAPI: OpenWeatherAPI, @unchecked Sendable {
    var currentWeatherCallCount = 0
    var forecastCallCount = 0
    var lastCurrentCityQuery: String?
    var lastCurrentLatitude: Double?
    var lastCurrentLongitude: Double?
    var lastCurrentUnits: WeatherUnits?
    var lastForecastCityQuery: String?
    var lastForecastLatitude: Double?
    var lastForecastLongitude: Double?

    private let currentResponse: CurrentWeatherResponse
    private let forecastResponse: ForecastResponse
    private let currentError: Error?

    init(
        currentResponse: CurrentWeatherResponse = currentWeatherResponse(),
        forecastResponse: ForecastResponse = ForecastResponse(list: []),
        currentError: Error? = nil
    ) {
        self.currentResponse = currentResponse
        self.forecastResponse = forecastResponse
        self.currentError = currentError
    }

    func currentWeather(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> CurrentWeatherResponse {
        currentWeatherCallCount += 1
        lastCurrentCityQuery = cityQuery
        lastCurrentLatitude = latitude
        lastCurrentLongitude = longitude
        lastCurrentUnits = units
        if let currentError { throw currentError }
        return currentResponse
    }

    func forecast(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> ForecastResponse {
        forecastCallCount += 1
        lastForecastCityQuery = cityQuery
        lastForecastLatitude = latitude
        lastForecastLongitude = longitude
        return forecastResponse
    }
}

private func currentWeatherResponse() -> CurrentWeatherResponse {
    CurrentWeatherResponse(
        name: "OpenWeather City",
        weather: [
            WeatherDescDTO(main: "Clear", description: "clear sky", icon: "01d"),
        ],
        main: MainDTO(temp: 72.5, feelsLike: 70.0, humidity: 42),
        wind: WindDTO(speed: 5.5)
    )
}

private func forecastItem(epochSeconds: Int, temperature: Double, main: String) -> ForecastListItemDTO {
    ForecastListItemDTO(
        dt: epochSeconds,
        main: MainDTO(temp: temperature, feelsLike: temperature - 1.0, humidity: 50),
        weather: [
            WeatherDescDTO(
                main: main,
                description: "\(main.lowercased()) description",
                icon: "01d"
            ),
        ]
    )
}
