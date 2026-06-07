import Foundation

@MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard
    private let hasSeenWelcomeKey = "has_seen_welcome"
    private let lastCityKey = "last_city"

    var hasSeenWelcome: Bool {
        defaults.bool(forKey: hasSeenWelcomeKey)
    }

    var lastCity: String? {
        defaults.string(forKey: lastCityKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func setHasSeenWelcome(_ value: Bool) {
        defaults.set(value, forKey: hasSeenWelcomeKey)
    }

    func setLastCity(_ cityName: String) {
        defaults.set(cityName, forKey: lastCityKey)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
