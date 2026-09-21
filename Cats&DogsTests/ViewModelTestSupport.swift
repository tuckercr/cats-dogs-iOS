import XCTest
@testable import Cats_Dogs

/// A `PreferencesStore` backed by a throwaway `UserDefaults` suite, so tests never touch real app data.
@MainActor
final class IsolatedPreferences {
    let store: PreferencesStore
    private let suiteName = "CatsDogsTests-\(UUID().uuidString)"

    init() {
        store = PreferencesStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    /// A second store over the same suite, to prove values were persisted rather than held in memory.
    func reopened() -> PreferencesStore {
        PreferencesStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    func destroy() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

/// View models start unstructured tasks; poll until their effect is visible.
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("Timed out waiting for condition", file: file, line: line)
            return
        }
        try? await Task.sleep(for: .milliseconds(2))
    }
}

/// Lets the code that was waiting on a fake request run to completion, for asserting that something
/// did *not* happen. A sleep alone proves nothing on a slow machine, so first `waitUntil` the fake
/// reports the request finished (`completedCurrentRequests`, `completedSearches`, …); this then only
/// has to cover the hop from the fake returning to the view model acting on the result.
@MainActor
func settle() async {
    for _ in 0..<10 { await Task.yield() }
    try? await Task.sleep(for: .milliseconds(40))
}

/// Holds fake requests open until the test resolves them — the counterpart of `CompletableDeferred`.
/// Any number of requests may wait on the same gate; all are released together.
@MainActor
final class Gate<Value> {
    private var waiters: [CheckedContinuation<Value, Error>] = []
    private var result: Result<Value, Error>?

    func value() async throws -> Value {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { waiters.append($0) }
    }

    func succeed(_ value: Value) { resolve(.success(value)) }
    func fail(_ error: Error) { resolve(.failure(error)) }

    private func resolve(_ newResult: Result<Value, Error>) {
        result = newResult
        waiters.forEach { $0.resume(with: newResult) }
        waiters = []
    }
}

struct WeatherRequest: Equatable {
    let cityQuery: String?
    let latitude: Double?
    let longitude: Double?
    let units: WeatherUnits
}

@MainActor
final class ScriptedWeatherAPI: OpenWeatherAPI, @unchecked Sendable {
    private(set) var currentRequests: [WeatherRequest] = []
    private(set) var forecastRequests: [WeatherRequest] = []
    /// Requests that have returned or thrown — wait on these before asserting a result was ignored.
    private(set) var completedCurrentRequests = 0
    private(set) var completedForecastRequests = 0

    var onCurrent: (WeatherRequest) async throws -> CurrentWeatherResponse = { request in
        weatherResponse(name: request.cityQuery ?? "Somewhere")
    }
    var onForecast: (WeatherRequest) async throws -> ForecastResponse = { _ in
        forecastResponse()
    }

    @MainActor
    func currentWeather(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> CurrentWeatherResponse {
        let request = WeatherRequest(cityQuery: cityQuery, latitude: latitude, longitude: longitude, units: units)
        currentRequests.append(request)
        defer { completedCurrentRequests += 1 }
        return try await onCurrent(request)
    }

    @MainActor
    func forecast(
        cityQuery: String?,
        latitude: Double?,
        longitude: Double?,
        units: WeatherUnits
    ) async throws -> ForecastResponse {
        let request = WeatherRequest(cityQuery: cityQuery, latitude: latitude, longitude: longitude, units: units)
        forecastRequests.append(request)
        defer { completedForecastRequests += 1 }
        return try await onForecast(request)
    }

    var repository: WeatherRepository {
        WeatherRepository(client: self, timeZone: TimeZone(identifier: "UTC")!)
    }
}

@MainActor
final class ScriptedGeocodingAPI: GeocodingAPI, @unchecked Sendable {
    private(set) var queries: [String] = []
    /// Searches that have returned or thrown — wait on this before asserting a result was ignored.
    private(set) var completedSearches = 0

    var onSearch: (String) async throws -> [GeocodingDirectDTO] = { _ in [] }

    @MainActor
    func directSearch(query: String, limit: Int) async throws -> [GeocodingDirectDTO] {
        queries.append(query)
        defer { completedSearches += 1 }
        return try await onSearch(query)
    }

    var repository: GeocodingRepository {
        GeocodingRepository(client: self)
    }
}

@MainActor
func weatherResponse(name: String = "Austin", temperature: Double = 21.0) -> CurrentWeatherResponse {
    CurrentWeatherResponse(
        name: name,
        weather: [WeatherDescDTO(main: "Clear", description: "clear sky", icon: "01d")],
        main: MainDTO(temp: temperature, feelsLike: temperature - 1, humidity: 50),
        wind: WindDTO(speed: 3.0),
        visibility: 10_000,
        clouds: CloudsDTO(all: 10),
        sys: nil
    )
}

@MainActor
func forecastResponse(temperature: Double = 18.0) -> ForecastResponse {
    ForecastResponse(list: [
        ForecastListItemDTO(
            dt: 1_700_049_600,
            main: MainDTO(temp: temperature, feelsLike: temperature - 1, humidity: 50),
            weather: [WeatherDescDTO(main: "Clouds", description: "scattered clouds", icon: "03d")],
            wind: WindDTO(speed: 1.0)
        ),
    ])
}

@MainActor
func geocodingResult(
    name: String,
    country: String = "US",
    state: String? = nil,
    lat: Double = 30.27,
    lon: Double = -97.74
) -> GeocodingDirectDTO {
    GeocodingDirectDTO(name: name, lat: lat, lon: lon, country: country, state: state)
}

extension LoadingState {
    var successValue: T? {
        if case .success(let value) = self { return value }
        return nil
    }
}

/// Builds domain models through the real repository mapping rather than hand-rolled initialisers.
@MainActor
func makeCurrentWeather(
    cityName: String = "Austin",
    temperature: Double = 21.0,
    units: WeatherUnits = .metric
) async -> CurrentWeather {
    let api = ScriptedWeatherAPI()
    api.onCurrent = { _ in weatherResponse(name: cityName, temperature: temperature) }
    let result = await api.repository.fetchCurrentWeather(
        units: units, locationLabel: cityName, cityQuery: cityName, latitude: nil, longitude: nil
    )
    return try! result.get()
}

@MainActor
func makeForecast(temperature: Double = 18.0, units: WeatherUnits = .metric) async -> [DayForecast] {
    let api = ScriptedWeatherAPI()
    api.onForecast = { _ in forecastResponse(temperature: temperature) }
    let result = await api.repository.fetchForecast(units: units, cityQuery: "Austin", latitude: nil, longitude: nil)
    return try! result.get()
}
