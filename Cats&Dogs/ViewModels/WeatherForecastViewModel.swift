import Foundation
import Observation

@MainActor
@Observable
final class WeatherForecastViewModel {
    private(set) var currentWeather: LoadingState<CurrentWeather> = .idle
    private(set) var forecast: LoadingState<[DayForecast]> = .idle
    private(set) var isRefreshing = false

    private let preferences: PreferencesStore
    private let weatherRepository: WeatherRepository

    private var currentFetchGeneration = 0
    private var forecastFetchGeneration = 0
    private var currentRefreshing = false
    private var forecastRefreshing = false
    private var currentTargetKey: String?
    private var forecastTargetKey: String?

    init(
        preferences: PreferencesStore? = nil,
        weatherRepository: WeatherRepository? = nil
    ) {
        self.preferences = preferences ?? .shared
        self.weatherRepository = weatherRepository ?? WeatherRepository()
    }

    func backgroundRefreshCurrent(location: SavedLocation) {
        Task {
            let units = resolvedUnits()
            let result = await fetchCurrent(for: location, units: units)
            if let target = currentTargetKey, target != location.cacheKey { return }
            if case .success(let weather) = result {
                currentWeather = .success(weather)
                preferences.setLastCity(weather.cityName)
                preferences.setCachedWeather(weather, for: location.cacheKey)
            }
        }
    }

    func backgroundRefreshForecast(location: SavedLocation) {
        Task {
            let units = resolvedUnits()
            let result = await fetchForecast(for: location, units: units)
            if let target = forecastTargetKey, target != location.cacheKey { return }
            if case .success(let days) = result {
                forecast = .success(days)
                preferences.setCachedForecast(days, for: location.cacheKey)
            }
        }
    }

    func refreshCurrent(location: SavedLocation) {
        currentTargetKey = location.cacheKey
        currentFetchGeneration += 1
        let fetchId = currentFetchGeneration
        currentRefreshing = true
        updateRefreshingState()

        Task {
            let cached = preferences.cachedWeather(for: location.cacheKey)
            currentWeather = cached.map { .success($0) } ?? .loading

            let units = resolvedUnits()
            let result = await fetchCurrent(for: location, units: units)

            guard fetchId == currentFetchGeneration else { return }
            switch result {
            case .success(let weather):
                preferences.setLastCity(weather.cityName)
                preferences.setCachedWeather(weather, for: location.cacheKey)
                currentWeather = .success(weather)
            case .failure(let error):
                if cached == nil {
                    currentWeather = .error(
                        errorKey: WeatherErrorMessages.errorKey(for: error),
                        canRetry: WeatherErrorMessages.canRetry(for: error)
                    )
                }
            }

            if fetchId == currentFetchGeneration {
                currentRefreshing = false
                updateRefreshingState()
            }
        }
    }

    func refreshForecast(location: SavedLocation) {
        forecastTargetKey = location.cacheKey
        forecastFetchGeneration += 1
        let fetchId = forecastFetchGeneration
        forecastRefreshing = true
        updateRefreshingState()

        Task {
            let cached = preferences.cachedForecast(for: location.cacheKey)
            forecast = cached.map { .success($0) } ?? .loading

            let units = resolvedUnits()
            let result = await fetchForecast(for: location, units: units)

            guard fetchId == forecastFetchGeneration else { return }
            switch result {
            case .success(let days):
                preferences.setCachedForecast(days, for: location.cacheKey)
                forecast = .success(days)
            case .failure(let error):
                if cached == nil {
                    forecast = .error(
                        errorKey: WeatherErrorMessages.errorKey(for: error),
                        canRetry: WeatherErrorMessages.canRetry(for: error)
                    )
                }
            }

            if fetchId == forecastFetchGeneration {
                forecastRefreshing = false
                updateRefreshingState()
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

    private func resolvedUnits() -> WeatherUnits {
        WeatherUnitsResolver.resolve(override: preferences.unitOverride)
    }

    private func updateRefreshingState() {
        isRefreshing = currentRefreshing || forecastRefreshing
    }

    private func fetchCurrent(
        for location: SavedLocation,
        units: WeatherUnits
    ) async -> Result<CurrentWeather, Error> {
        let label = location.isCurrentLocation ? "" : location.label
        if let latitude = location.latitude, let longitude = location.longitude {
            return await weatherRepository.fetchCurrentWeather(
                units: units,
                locationLabel: label,
                cityQuery: nil,
                latitude: latitude,
                longitude: longitude
            )
        }
        return await weatherRepository.fetchCurrentWeather(
            units: units,
            locationLabel: label,
            cityQuery: location.label,
            latitude: nil,
            longitude: nil
        )
    }

    private func fetchForecast(
        for location: SavedLocation,
        units: WeatherUnits
    ) async -> Result<[DayForecast], Error> {
        if let latitude = location.latitude, let longitude = location.longitude {
            return await weatherRepository.fetchForecast(
                units: units,
                cityQuery: nil,
                latitude: latitude,
                longitude: longitude
            )
        }
        return await weatherRepository.fetchForecast(
            units: units,
            cityQuery: location.label,
            latitude: nil,
            longitude: nil
        )
    }
}
