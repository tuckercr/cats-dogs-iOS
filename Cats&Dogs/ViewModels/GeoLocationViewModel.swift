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

    init(geocodingRepository: GeocodingRepository = GeocodingRepository()) {
        self.geocodingRepository = geocodingRepository
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
