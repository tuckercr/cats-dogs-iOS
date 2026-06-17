import SwiftUI

private enum AppScreen: Hashable {
    case forecast
}

struct RootView: View {
    @State private var welcomeViewModel = WelcomeViewModel()
    @State private var cityListViewModel = CityListViewModel()
    @State private var geoViewModel = GeoLocationViewModel()
    @State private var weatherViewModel = WeatherForecastViewModel()
    @State private var path: [AppScreen] = []

    var body: some View {
        Group {
            if let state = welcomeViewModel.onboardingState {
                if !state.hasSeenWelcome {
                    WelcomeView {
                        welcomeViewModel.completeWelcome()
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
                            onOpenForecast: { path.append(.forecast) }
                        )
                        .navigationDestination(for: AppScreen.self) { screen in
                            switch screen {
                            case .forecast:
                                ForecastView(
                                    cityListViewModel: cityListViewModel,
                                    weatherViewModel: weatherViewModel
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
