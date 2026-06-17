import Foundation
import Observation

struct OnboardingState: Equatable {
    var hasSeenWelcome: Bool
    var locationOnboardingDone: Bool
}

@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var onboardingState: OnboardingState?

    private let preferences: PreferencesStore

    init(preferences: PreferencesStore = .shared) {
        self.preferences = preferences
        onboardingState = OnboardingState(
            hasSeenWelcome: preferences.hasSeenWelcome,
            locationOnboardingDone: preferences.locationOnboardingDone
        )
    }

    func completeWelcome() {
        preferences.setHasSeenWelcome(true)
        onboardingState = onboardingState.map { state in
            var updated = state
            updated.hasSeenWelcome = true
            return updated
        }
    }

    func completeLocationOnboarding() {
        preferences.setLocationOnboardingDone()
        onboardingState = onboardingState.map { state in
            var updated = state
            updated.locationOnboardingDone = true
            return updated
        }
    }
}
