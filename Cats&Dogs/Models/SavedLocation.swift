import Foundation

/// A city pinned by the user. Coordinates may be nil for name-only entries (legacy migration).
struct SavedLocation: Codable, Equatable, Identifiable {
    var id: String { cacheKey }
    let label: String
    let latitude: Double?
    let longitude: Double?
    let isCurrentLocation: Bool

    var cacheKey: String {
        if let latitude, let longitude {
            return String(format: "%.4f,%.4f", latitude, longitude)
        }
        return label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    init(
        label: String,
        latitude: Double?,
        longitude: Double?,
        isCurrentLocation: Bool = false
    ) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
    }
}
