import XCTest
@testable import Cats_Dogs

@MainActor
final class WelcomeViewModelTests: XCTestCase {
    private var preferences: IsolatedPreferences!

    override func setUp() async throws {
        preferences = IsolatedPreferences()
    }

    override func tearDown() async throws {
        preferences.destroy()
    }

    func testFreshInstallHasNothingCompleted() {
        let viewModel = WelcomeViewModel(preferences: preferences.store)

        XCTAssertEqual(
            viewModel.onboardingState,
            OnboardingState(hasSeenWelcome: false, notificationOnboardingDone: false, locationOnboardingDone: false)
        )
    }

    func testInitialStateReflectsStoredFlags() {
        preferences.store.setHasSeenWelcome(true)
        preferences.store.setNotificationOnboardingDone()

        let viewModel = WelcomeViewModel(preferences: preferences.store)

        XCTAssertEqual(
            viewModel.onboardingState,
            OnboardingState(hasSeenWelcome: true, notificationOnboardingDone: true, locationOnboardingDone: false)
        )
    }

    func testCompleteWelcomeMarksStateDoneAndPersists() {
        let viewModel = WelcomeViewModel(preferences: preferences.store)

        viewModel.completeWelcome()

        XCTAssertEqual(viewModel.onboardingState?.hasSeenWelcome, true)
        XCTAssertEqual(viewModel.onboardingState?.notificationOnboardingDone, false)
        XCTAssertTrue(preferences.reopened().hasSeenWelcome)
    }

    func testWelcomeLeadsToTheDogQuestionOnlyInTheSameRun() {
        let viewModel = WelcomeViewModel(preferences: preferences.store)
        XCTAssertFalse(viewModel.isAskingAboutDog)

        viewModel.completeWelcome()
        XCTAssertTrue(viewModel.isAskingAboutDog)

        viewModel.completeDogQuestion()
        XCTAssertFalse(viewModel.isAskingAboutDog)
        XCTAssertFalse(
            WelcomeViewModel(preferences: preferences.reopened()).isAskingAboutDog,
            "A later launch, or an existing user after an update, isn't asked"
        )
    }

    func testCompleteNotificationOnboardingMarksStateDoneAndPersists() {
        let viewModel = WelcomeViewModel(preferences: preferences.store)

        viewModel.completeNotificationOnboarding()

        XCTAssertEqual(viewModel.onboardingState?.notificationOnboardingDone, true)
        XCTAssertEqual(viewModel.onboardingState?.locationOnboardingDone, false)
        XCTAssertTrue(preferences.reopened().notificationOnboardingDone)
    }

    func testCompleteLocationOnboardingMarksStateDoneAndPersists() {
        let viewModel = WelcomeViewModel(preferences: preferences.store)

        viewModel.completeLocationOnboarding()

        XCTAssertEqual(viewModel.onboardingState?.locationOnboardingDone, true)
        XCTAssertTrue(preferences.reopened().locationOnboardingDone)
    }

    func testOnlyTheLastOnboardingStepReportsOnboardingComplete() {
        var completions = 0
        let viewModel = WelcomeViewModel(preferences: preferences.store, onOnboardingComplete: { completions += 1 })

        viewModel.completeWelcome()
        viewModel.completeNotificationOnboarding()
        XCTAssertEqual(completions, 0)

        viewModel.completeLocationOnboarding()
        XCTAssertEqual(completions, 1)
    }

    /// Installs from before the notification step existed must not be sent back through onboarding.
    func testLegacyInstallThatFinishedLocationOnboardingSkipsNotificationStep() {
        preferences.store.setHasSeenWelcome(true)
        preferences.store.setLocationOnboardingDone()

        let viewModel = WelcomeViewModel(preferences: preferences.store)

        XCTAssertEqual(viewModel.onboardingState?.notificationOnboardingDone, true)
    }
}
