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
        pruneCache(keeping: locations)
    }

    func setActiveLocationIndex(_ index: Int) {
        defaults.set(index, forKey: activeLocationIndexKey)
    }

    func setUnitOverride(_ override: UnitOverride) {
        defaults.set(override.rawValue, forKey: unitOverrideKey)
    }

    func cachedWeather(for locationKey: String) -> CurrentWeather? {
        loadCache(CurrentWeather.self, forKey: weatherCacheKey)[locationKey]
    }

    func setCachedWeather(_ weather: CurrentWeather, for locationKey: String) {
        var cache = loadCache(CurrentWeather.self, forKey: weatherCacheKey)
        cache[locationKey] = weather
        saveCache(cache, forKey: weatherCacheKey)
    }

    func cachedForecast(for locationKey: String) -> [DayForecast]? {
        loadCache([DayForecast].self, forKey: forecastCacheKey)[locationKey]
    }

    func setCachedForecast(_ forecast: [DayForecast], for locationKey: String) {
        var cache = loadCache([DayForecast].self, forKey: forecastCacheKey)
        cache[locationKey] = forecast
        saveCache(cache, forKey: forecastCacheKey)
    }

    func clearCache() {
        defaults.removeObject(forKey: weatherCacheKey)
        defaults.removeObject(forKey: forecastCacheKey)
    }

    /// Drops cache entries for cities that are no longer saved, so removed cities (and every spot
    /// "My Location" has ever resolved to) don't pile up in UserDefaults.
    private func pruneCache(keeping locations: [SavedLocation]) {
        let keys = Set(locations.map(\.cacheKey))
        prune(CurrentWeather.self, forKey: weatherCacheKey, keeping: keys)
        prune([DayForecast].self, forKey: forecastCacheKey, keeping: keys)
    }

    private func prune<Value: Codable>(_ type: Value.Type, forKey key: String, keeping keys: Set<String>) {
        let cache = loadCache(type, forKey: key)
        let pruned = cache.filter { keys.contains($0.key) }
        if pruned.count != cache.count {
            saveCache(pruned, forKey: key)
        }
    }

    /// Unreadable data (including the older string-in-a-map format) is treated as an empty cache.
    private func loadCache<Value: Codable>(_ type: Value.Type, forKey key: String) -> [String: Value] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? decoder.decode([String: Value].self, from: data)) ?? [:]
    }

    private func saveCache<Value: Codable>(_ cache: [String: Value], forKey key: String) {
        guard let data = try? encoder.encode(cache) else { return }
        defaults.set(data, forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
