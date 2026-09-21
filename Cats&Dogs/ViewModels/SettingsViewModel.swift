import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var unitOverride: UnitOverride

    private let preferences: PreferencesStore

    init(preferences: PreferencesStore? = nil) {
        let preferences = preferences ?? .shared
        self.preferences = preferences
        unitOverride = preferences.unitOverride
    }

    func setUnitOverride(_ override: UnitOverride) {
        unitOverride = override
        preferences.setUnitOverride(override)
    }

    func clearCache() {
        preferences.clearCache()
    }
}
