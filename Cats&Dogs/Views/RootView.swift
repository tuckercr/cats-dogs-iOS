import SwiftUI

private enum AppScreen: Hashable {
    case settings
    case locations
}

struct RootView: View {
    @State private var welcomeViewModel = WelcomeViewModel()
    @State private var cityListViewModel = CityListViewModel()
    @State private var geoViewModel = GeoLocationViewModel()
    @State private var weatherViewModel = WeatherForecastViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var path: [AppScreen] = []

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
                                    onOpenLocations: { path.append(.locations) },
                                    onLocationResolved: { cityListViewModel.addLocation($0) }
                                )
                            case .locations:
                                LocationsView(
                                    cityListViewModel: cityListViewModel,
                                    geoViewModel: geoViewModel
                                )
                            }
                        }
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
