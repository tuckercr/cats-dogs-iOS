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
    /// True between the welcome screen and the "Is there a dog at home?" answer. In memory only: the step is
    /// part of a new user's first run, not resumed on a later launch, and not shown after an update.
    private(set) var isAskingAboutDog = false

    private let preferences: PreferencesStore
    private let onOnboardingComplete: @MainActor () -> Void

    init(
        preferences: PreferencesStore? = nil,
        onOnboardingComplete: (@MainActor () -> Void)? = nil
    ) {
        let preferences = preferences ?? .shared
        self.preferences = preferences
        self.onOnboardingComplete = onOnboardingComplete ?? { AnalyticsRepository.shared.logOnboardingComplete() }
        onboardingState = OnboardingState(
            hasSeenWelcome: preferences.hasSeenWelcome,
            notificationOnboardingDone: preferences.notificationOnboardingDone,
            locationOnboardingDone: preferences.locationOnboardingDone
        )
    }

    func completeWelcome() {
        preferences.setHasSeenWelcome(true)
        isAskingAboutDog = true
        onboardingState = onboardingState.map { state in
            var updated = state
            updated.hasSeenWelcome = true
            return updated
        }
    }

    /// Moves on from "Is there a dog at home?". The answer itself goes to `SettingsViewModel.setShowWalkCard`.
    func completeDogQuestion() {
        isAskingAboutDog = false
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
        onOnboardingComplete()
    }
}
