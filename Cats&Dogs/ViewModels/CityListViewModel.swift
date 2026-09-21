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
    private let geocodingRepository: GeocodingRepository

    init(
        preferences: PreferencesStore? = nil,
        geocodingRepository: GeocodingRepository? = nil
    ) {
        self.preferences = preferences ?? .shared
        self.geocodingRepository = geocodingRepository ?? GeocodingRepository()
        loadFromPreferences()
    }

    func addLocation(_ location: SavedLocation) {
        if let existingIndex = locations.firstIndex(where: { $0.label == location.label }) {
            setActiveIndex(existingIndex)
            return
        }

        // Append before any await so the city shows up at once (even offline) and a second add of
        // the same label hits the duplicate check above.
        let updated = locations + [location]
        let newIndex = updated.count - 1
        locations = updated
        activeIndex = newIndex
        preferences.setSavedLocations(updated)
        preferences.setActiveLocationIndex(newIndex)

        if location.latitude == nil || location.longitude == nil {
            Task { await fillInCoordinates(forLabel: location.label) }
        }
    }

    /// Geocodes a name-only entry so it gets a radar and an unambiguous forecast. The entered label
    /// is kept so the duplicate check in `addLocation` still matches it.
    private func fillInCoordinates(forLabel label: String) async {
        guard let geocoded = await geocodingRepository.searchCities(query: label).getOrNil()?.first,
              // The list may have changed while geocoding was in flight.
              let index = locations.firstIndex(where: { $0.label == label && $0.latitude == nil })
        else { return }

        var updated = locations
        updated[index] = SavedLocation(
            label: label,
            latitude: geocoded.weatherLat,
            longitude: geocoded.weatherLon,
            isCurrentLocation: updated[index].isCurrentLocation
        )
        locations = updated
        preferences.setSavedLocations(updated)
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

    func reorderLocations(from source: IndexSet, to destination: Int) {
        guard let fromIndex = source.first else { return }
        reorderLocations(fromIndex: fromIndex, toIndex: destination)
    }

    func reorderLocations(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              locations.indices.contains(fromIndex),
              toIndex >= 0,
              toIndex <= locations.count else { return }

        var updated = locations
        let item = updated.remove(at: fromIndex)
        let adjustedDestination = toIndex > fromIndex ? toIndex - 1 : toIndex
        updated.insert(item, at: adjustedDestination)

        let newActiveIndex: Int
        if activeIndex == fromIndex {
            newActiveIndex = adjustedDestination
        } else if fromIndex < activeIndex && adjustedDestination >= activeIndex {
            newActiveIndex = activeIndex - 1
        } else if fromIndex > activeIndex && adjustedDestination <= activeIndex {
            newActiveIndex = activeIndex + 1
        } else {
            newActiveIndex = activeIndex
        }

        locations = updated
        activeIndex = newActiveIndex
        preferences.setSavedLocations(updated)
        preferences.setActiveLocationIndex(newActiveIndex)
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

private extension Result {
    func getOrNil() -> Success? {
        if case .success(let value) = self { return value }
        return nil
    }
}
