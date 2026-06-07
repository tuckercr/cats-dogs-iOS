import Foundation
import Observation

@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var welcomeDone: Bool?

    private let preferences: PreferencesStore

    init(preferences: PreferencesStore = .shared) {
        self.preferences = preferences
        welcomeDone = preferences.hasSeenWelcome
    }

    func completeWelcome() {
        welcomeDone = true
        preferences.setHasSeenWelcome(true)
    }
}
