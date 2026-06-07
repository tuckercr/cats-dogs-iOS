import Foundation
import Observation

@MainActor
@Observable
final class GeoLocationViewModel {
    var cityInput = ""
    private(set) var citySuggestions: [CitySuggestion] = []
    private(set) var citySuggestLoading = false

    private(set) var pinnedLatitude: Double?
    private(set) var pinnedLongitude: Double?

    private let preferences: PreferencesStore
    private let geocodingRepository: GeocodingRepository
    private var suggestTask: Task<Void, Never>?
    private var savedCityRestoreDone = false

    init(
        preferences: PreferencesStore = .shared,
        geocodingRepository: GeocodingRepository = GeocodingRepository()
    ) {
        self.preferences = preferences
        self.geocodingRepository = geocodingRepository
    }

    func onCityInputChange(_ value: String) {
        cityInput = value
        pinnedLatitude = nil
        pinnedLongitude = nil
        suggestTask?.cancel()

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            citySuggestions = []
            citySuggestLoading = false
            return
        }

        suggestTask = Task {
            citySuggestLoading = true
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, cityInput.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else {
                citySuggestLoading = false
                return
            }

            let result = await geocodingRepository.searchCities(query: trimmed)
            guard !Task.isCancelled, cityInput.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else {
                citySuggestLoading = false
                return
            }

            citySuggestLoading = false
            citySuggestions = (try? result.get()) ?? []
        }
    }

    func onCitySuggestionChosen(_ suggestion: CitySuggestion) {
        suggestTask?.cancel()
        citySuggestions = []
        citySuggestLoading = false
        pinnedLatitude = suggestion.weatherLat
        pinnedLongitude = suggestion.weatherLon
        cityInput = suggestion.label
    }

    func dismissSuggestions() {
        suggestTask?.cancel()
        citySuggestions = []
        citySuggestLoading = false
    }

    func restoreSavedCityOnce() -> String? {
        guard !savedCityRestoreDone else { return nil }
        savedCityRestoreDone = true
        guard let last = preferences.lastCity else { return nil }
        cityInput = last
        return last
    }
}
