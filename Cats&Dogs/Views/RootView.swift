import SwiftUI

private enum AppScreen: Hashable {
    case forecast
}

struct RootView: View {
    @State private var welcomeViewModel = WelcomeViewModel()
    @State private var geoViewModel = GeoLocationViewModel()
    @State private var weatherViewModel = WeatherForecastViewModel()
    @State private var path: [AppScreen] = []

    var body: some View {
        Group {
            if welcomeViewModel.welcomeDone != true {
                WelcomeView {
                    welcomeViewModel.completeWelcome()
                }
            } else {
                NavigationStack(path: $path) {
                    CurrentWeatherView(
                        geoViewModel: geoViewModel,
                        weatherViewModel: weatherViewModel,
                        onOpenForecast: { path.append(.forecast) }
                    )
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .forecast:
                            ForecastView(
                                geoViewModel: geoViewModel,
                                weatherViewModel: weatherViewModel
                            )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RootView()
}
