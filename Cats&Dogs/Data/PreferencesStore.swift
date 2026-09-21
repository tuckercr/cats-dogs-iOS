import Foundation

@MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults: UserDefaults
    private let hasSeenWelcomeKey = "has_seen_welcome"
    private let locationOnboardingDoneKey = "location_onboarding_done"
    private let notificationOnboardingDoneKey = "notification_onboarding_done"
    private let lastCityKey = "last_city"
    private let savedLocationsKey = "saved_locations"
    private let activeLocationIndexKey = "active_location_index"
    private let weatherCacheKey = "weather_cache"
    private let forecastCacheKey = "forecast_cache"
    private let unitOverrideKey = "unit_override"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeenWelcome: Bool {
        defaults.bool(forKey: hasSeenWelcomeKey)
    }

    var locationOnboardingDone: Bool {
        defaults.bool(forKey: locationOnboardingDoneKey)
    }

    var notificationOnboardingDone: Bool {
        if defaults.object(forKey: notificationOnboardingDoneKey) != nil {
            return defaults.bool(forKey: notificationOnboardingDoneKey)
        }
        // Legacy installs that completed location onboarding before this flag existed.
        return locationOnboardingDone
    }

    var lastCity: String? {
        defaults.string(forKey: lastCityKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    var savedLocations: [SavedLocation] {
        guard let data = defaults.data(forKey: savedLocationsKey) else { return [] }
        return (try? decoder.decode([SavedLocation].self, from: data)) ?? []
    }

    var activeLocationIndex: Int {
        defaults.integer(forKey: activeLocationIndexKey)
    }

    var unitOverride: UnitOverride {
        guard let raw = defaults.string(forKey: unitOverrideKey) else { return .system }
        return UnitOverride(rawValue: raw) ?? .system
    }

    func setHasSeenWelcome(_ value: Bool) {
        defaults.set(value, forKey: hasSeenWelcomeKey)
    }

    func setLocationOnboardingDone() {
        defaults.set(true, forKey: locationOnboardingDoneKey)
    }

    func setNotificationOnboardingDone() {
        defaults.set(true, forKey: notificationOnboardingDoneKey)
    }

    func setLastCity(_ cityName: String) {
        defaults.set(cityName, forKey: lastCityKey)
    }

    func setSavedLocations(_ locations: [SavedLocation]) {
        guard let data = try? encoder.encode(locations) else { return }
        defaults.set(data, forKey: savedLocationsKey)
    }

    func setActiveLocationIndex(_ index: Int) {
        defaults.set(index, forKey: activeLocationIndexKey)
    }

    func setUnitOverride(_ override: UnitOverride) {
        defaults.set(override.rawValue, forKey: unitOverrideKey)
    }

    func cachedWeather(for locationKey: String) -> CurrentWeather? {
        guard let map = loadCacheMap(forKey: weatherCacheKey),
              let raw = map[locationKey],
              let data = raw.data(using: .utf8) else { return nil }
        return try? decoder.decode(CurrentWeather.self, from: data)
    }

    func setCachedWeather(_ weather: CurrentWeather, for locationKey: String) {
        guard let data = try? encoder.encode(weather),
              let json = String(data: data, encoding: .utf8) else { return }
        var map = loadCacheMap(forKey: weatherCacheKey) ?? [:]
        map[locationKey] = json
        saveCacheMap(map, forKey: weatherCacheKey)
    }

    func cachedForecast(for locationKey: String) -> [DayForecast]? {
        guard let map = loadCacheMap(forKey: forecastCacheKey),
              let raw = map[locationKey],
              let data = raw.data(using: .utf8) else { return nil }
        return try? decoder.decode([DayForecast].self, from: data)
    }

    func setCachedForecast(_ forecast: [DayForecast], for locationKey: String) {
        guard let data = try? encoder.encode(forecast),
              let json = String(data: data, encoding: .utf8) else { return }
        var map = loadCacheMap(forKey: forecastCacheKey) ?? [:]
        map[locationKey] = json
        saveCacheMap(map, forKey: forecastCacheKey)
    }

    func clearCache() {
        defaults.removeObject(forKey: weatherCacheKey)
        defaults.removeObject(forKey: forecastCacheKey)
    }

    private func loadCacheMap(forKey key: String) -> [String: String]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode([String: String].self, from: data)
    }

    private func saveCacheMap(_ map: [String: String], forKey key: String) {
        guard let data = try? encoder.encode(map) else { return }
        defaults.set(data, forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
