import Foundation

@MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard
    private let hasSeenWelcomeKey = "has_seen_welcome"
    private let locationOnboardingDoneKey = "location_onboarding_done"
    private let lastCityKey = "last_city"
    private let savedLocationsKey = "saved_locations"
    private let activeLocationIndexKey = "active_location_index"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var hasSeenWelcome: Bool {
        defaults.bool(forKey: hasSeenWelcomeKey)
    }

    var locationOnboardingDone: Bool {
        defaults.bool(forKey: locationOnboardingDoneKey)
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

    func setHasSeenWelcome(_ value: Bool) {
        defaults.set(value, forKey: hasSeenWelcomeKey)
    }

    func setLocationOnboardingDone() {
        defaults.set(true, forKey: locationOnboardingDoneKey)
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
