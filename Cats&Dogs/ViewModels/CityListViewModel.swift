import Foundation
import Observation

@MainActor
@Observable
final class CityListViewModel {
    private(set) var locations: [SavedLocation] = []
    private(set) var activeIndex = 0

    var activeLocation: SavedLocation? {
        locations.indices.contains(activeIndex) ? locations[activeIndex] : nil
    }

    private let preferences: PreferencesStore

    init(preferences: PreferencesStore = .shared) {
        self.preferences = preferences
        loadFromPreferences()
    }

    func addLocation(_ location: SavedLocation) {
        if let existingIndex = locations.firstIndex(where: { $0.label == location.label }) {
            setActiveIndex(existingIndex)
            return
        }
        let updated = locations + [location]
        let newIndex = updated.count - 1
        locations = updated
        activeIndex = newIndex
        preferences.setSavedLocations(updated)
        preferences.setActiveLocationIndex(newIndex)
    }

    func removeLocation(at index: Int) {
        guard locations.indices.contains(index) else { return }
        var updated = locations
        updated.remove(at: index)
        let newIndex = min(activeIndex, max(updated.count - 1, 0))
        locations = updated
        activeIndex = newIndex
        preferences.setSavedLocations(updated)
        preferences.setActiveLocationIndex(newIndex)
    }

    func setActiveIndex(_ index: Int) {
        guard index != activeIndex, locations.indices.contains(index) else { return }
        activeIndex = index
        preferences.setActiveLocationIndex(index)
    }

    private func loadFromPreferences() {
        var loaded = preferences.savedLocations
        if loaded.isEmpty, let lastCity = preferences.lastCity {
            loaded = [SavedLocation(label: lastCity, latitude: nil, longitude: nil)]
            preferences.setSavedLocations(loaded)
        }
        locations = loaded
        activeIndex = min(preferences.activeLocationIndex, max(loaded.count - 1, 0))
    }
}
