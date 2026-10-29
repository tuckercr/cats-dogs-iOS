import SwiftUI

private enum AppScreen: Hashable {
    case settings
    case notifications
    case locations
}

struct RootView: View {
    @State private var welcomeViewModel = WelcomeViewModel()
    @State private var cityListViewModel = CityListViewModel()
    @State private var geoViewModel = GeoLocationViewModel()
    @State private var weatherViewModel = WeatherForecastViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var path: [AppScreen] = []
    private let notificationSettingsLink = NotificationSettingsLink.shared

    var body: some View {
        Group {
            if let state = welcomeViewModel.onboardingState {
                if !state.hasSeenWelcome {
                    WelcomeView {
                        welcomeViewModel.completeWelcome()
                    }
                } else if welcomeViewModel.isAskingAboutDog {
                    OnboardingDogView { hasDog in
                        // The walk card only shows when there's a dog.
                        settingsViewModel.setShowWalkCard(hasDog)
                        welcomeViewModel.completeDogQuestion()
                    }
                } else if !state.notificationOnboardingDone {
                    OnboardingNotificationView {
                        welcomeViewModel.completeNotificationOnboarding()
                    }
                } else if !state.locationOnboardingDone {
                    OnboardingLocationView(
                        onLocationResolved: { location in
                            cityListViewModel.addLocation(location)
                            welcomeViewModel.completeLocationOnboarding()
                        },
                        onSkip: {
                            welcomeViewModel.completeLocationOnboarding()
                        }
                    )
                } else {
                    NavigationStack(path: $path) {
                        CurrentWeatherView(
                            cityListViewModel: cityListViewModel,
                            geoViewModel: geoViewModel,
                            weatherViewModel: weatherViewModel,
                            settingsViewModel: settingsViewModel,
                            onOpenSettings: {
                                weatherViewModel.logSettingsOpened()
                                path.append(.settings)
                            }
                        )
                        .navigationDestination(for: AppScreen.self) { screen in
                            switch screen {
                            case .settings:
                                SettingsView(
                                    settingsViewModel: settingsViewModel,
                                    onOpenNotifications: { path.append(.notifications) },
                                    onOpenLocations: { path.append(.locations) },
                                    onLocationResolved: { cityListViewModel.addLocation($0) }
                                )
                            case .notifications:
                                NotificationSettingsView(settingsViewModel: settingsViewModel)
                            case .locations:
                                LocationsView(
                                    cityListViewModel: cityListViewModel,
                                    geoViewModel: geoViewModel
                                )
                            }
                        }
                    }
                    // From the link in iOS Settings; waits here until onboarding is done.
                    .onChange(of: notificationSettingsLink.isRequested, initial: true) { _, requested in
                        guard requested else { return }
                        notificationSettingsLink.isRequested = false
                        path = [.settings, .notifications]
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    RootView()
}
