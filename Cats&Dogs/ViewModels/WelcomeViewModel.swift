import Foundation
import Observation

struct OnboardingState: Equatable {
    var hasSeenWelcome: Bool
    var notificationOnboardingDone: Bool
    var locationOnboardingDone: Bool
}

@MainActor
@Observable
final class WelcomeViewModel {
    private(set) var onboardingState: OnboardingState?

    private let preferences: PreferencesStore

    init(preferences: PreferencesStore? = nil) {
        let preferences = preferences ?? .shared
        self.preferences = preferences
        onboardingState = OnboardingState(
            hasSeenWelcome: preferences.hasSeenWelcome,
            notificationOnboardingDone: preferences.notificationOnboardingDone,
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

    func completeNotificationOnboarding() {
        preferences.setNotificationOnboardingDone()
        onboardingState = onboardingState.map { state in
            var updated = state
            updated.notificationOnboardingDone = true
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
