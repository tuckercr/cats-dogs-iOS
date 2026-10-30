import Foundation
import Observation

@MainActor
@Observable
final class GeoLocationViewModel {
    var cityInput = ""
    private(set) var citySuggestions: [CitySuggestion] = []
    private(set) var citySuggestLoading = false
    private(set) var selectedSuggestion: CitySuggestion?

    private let geocodingRepository: GeocodingRepository
    private var suggestTask: Task<Void, Never>?

    init(geocodingRepository: GeocodingRepository? = nil) {
        self.geocodingRepository = geocodingRepository ?? GeocodingRepository()
    }

    /// What Add city adds: the picked suggestion, otherwise the top one showing, otherwise the typed
    /// name (its coordinates are looked up later, so a city can be added offline). Nil with nothing
    /// typed.
    var locationToAdd: SavedLocation? {
        if let suggestion = selectedSuggestion ?? citySuggestions.first {
            return SavedLocation(label: suggestion.label, latitude: suggestion.weatherLat, longitude: suggestion.weatherLon)
        }
        let trimmed = cityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : SavedLocation(label: trimmed, latitude: nil, longitude: nil)
    }

    func onCityInputChange(_ value: String) {
        cityInput = value
        selectedSuggestion = nil
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
        selectedSuggestion = suggestion
        cityInput = suggestion.label
    }

    func dismissSuggestions() {
        suggestTask?.cancel()
        citySuggestions = []
        citySuggestLoading = false
    }

    func reset() {
        suggestTask?.cancel()
        cityInput = ""
        citySuggestions = []
        citySuggestLoading = false
        selectedSuggestion = nil
    }
}
