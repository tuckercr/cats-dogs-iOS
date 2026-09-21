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

        Task {
            let locationToAdd: SavedLocation
            if location.latitude == nil || location.longitude == nil {
                let geocoded = await geocodingRepository.searchCities(query: location.label)
                    .getOrNil()?
                    .first
                if let geocoded {
                    // Keep the entered label so the duplicate check above still matches it.
                    locationToAdd = SavedLocation(
                        label: location.label,
                        latitude: geocoded.weatherLat,
                        longitude: geocoded.weatherLon,
                        isCurrentLocation: location.isCurrentLocation
                    )
                } else {
                    locationToAdd = location
                }
            } else {
                locationToAdd = location
            }

            let updated = locations + [locationToAdd]
            let newIndex = updated.count - 1
            locations = updated
            activeIndex = newIndex
            preferences.setSavedLocations(updated)
            preferences.setActiveLocationIndex(newIndex)
        }
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
