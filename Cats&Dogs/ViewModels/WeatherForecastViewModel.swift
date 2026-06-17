import Foundation
import Observation

@MainActor
@Observable
final class WeatherForecastViewModel {
    private(set) var currentWeather: LoadingState<CurrentWeather> = .idle
    private(set) var forecast: LoadingState<[DayForecast]> = .idle

    private let preferences: PreferencesStore
    private let weatherRepository: WeatherRepository
    private var currentFetchGeneration = 0
    private var forecastFetchGeneration = 0

    init(
        preferences: PreferencesStore = .shared,
        weatherRepository: WeatherRepository = WeatherRepository()
    ) {
        self.preferences = preferences
        self.weatherRepository = weatherRepository
    }

    func refreshCurrent(location: SavedLocation) {
        currentFetchGeneration += 1
        let fetchId = currentFetchGeneration

        Task {
            currentWeather = .loading
            let units = WeatherUnits.current
            let result: Result<CurrentWeather, Error>
            if let latitude = location.latitude, let longitude = location.longitude {
                result = await weatherRepository.fetchCurrentWeather(
                    units: units,
                    locationLabel: location.label,
                    cityQuery: nil,
                    latitude: latitude,
                    longitude: longitude
                )
            } else {
                result = await weatherRepository.fetchCurrentWeather(
                    units: units,
                    locationLabel: location.label,
                    cityQuery: location.label,
                    latitude: nil,
                    longitude: nil
                )
            }

            guard fetchId == currentFetchGeneration else { return }
            switch result {
            case .success(let weather):
                preferences.setLastCity(weather.cityName)
                currentWeather = .success(weather)
            case .failure(let error):
                currentWeather = .error(
                    message: Self.userMessage(for: error),
                    canRetry: true
                )
            }
        }
    }

    func refreshForecast(location: SavedLocation) {
        forecastFetchGeneration += 1
        let fetchId = forecastFetchGeneration

        Task {
            forecast = .loading
            let units = WeatherUnits.current
            let result: Result<[DayForecast], Error>
            if let latitude = location.latitude, let longitude = location.longitude {
                result = await weatherRepository.fetchForecast(
                    units: units,
                    cityQuery: nil,
                    latitude: latitude,
                    longitude: longitude
                )
            } else {
                result = await weatherRepository.fetchForecast(
                    units: units,
                    cityQuery: location.label,
                    latitude: nil,
                    longitude: nil
                )
            }

            guard fetchId == forecastFetchGeneration else { return }
            switch result {
            case .success(let days):
                forecast = .success(days)
            case .failure(let error):
                forecast = .error(
                    message: Self.userMessage(for: error),
                    canRetry: true
                )
            }
        }
    }

    func clearCurrentError() {
        if case .error = currentWeather {
            currentWeather = .idle
        }
    }

    func clearForecastError() {
        if case .error = forecast {
            forecast = .idle
        }
    }

    private static func userMessage(for error: Error) -> String {
        if let clientError = error as? OpenWeatherClientError {
            switch clientError {
            case .missingApiKey:
                return "Weather API key is missing. Copy Secrets.example.plist to Secrets.plist and add your key."
            case .emptyQuery:
                return "Please enter a city name."
            case .network:
                return "We could not reach the weather service. Check your connection and try again."
            case .http(_, let message):
                return message
            case .invalidPayload:
                return "Weather data is not available right now. Please try again later."
            }
        }

        return error.localizedDescription.nilIfEmpty
            ?? "Weather data is not available right now. Please try again later."
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
