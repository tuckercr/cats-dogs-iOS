import Foundation

struct CitySuggestion: Equatable, Identifiable {
    var id: String { label }
    let label: String
    let weatherLat: Double
    let weatherLon: Double
}
