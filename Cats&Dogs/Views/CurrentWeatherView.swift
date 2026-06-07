import SwiftUI

struct CurrentWeatherView: View {
    @Bindable var geoViewModel: GeoLocationViewModel
    @Bindable var weatherViewModel: WeatherForecastViewModel
    let onOpenForecast: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                cityField
                getWeatherButton
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Current weather")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenForecast) {
                    Image(systemName: "calendar")
                }
                .disabled(weatherViewModel.resolvedCity == nil)
                .accessibilityLabel("Open forecast")
            }
        }
        .task {
            if let restoredCity = geoViewModel.restoreSavedCityOnce() {
                geoViewModel.dismissSuggestions()
                weatherViewModel.refreshCurrent(
                    city: restoredCity,
                    latitude: geoViewModel.pinnedLatitude,
                    longitude: geoViewModel.pinnedLongitude
                )
            }
        }
    }

    private var cityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("City", text: Binding(
                get: { geoViewModel.cityInput },
                set: { geoViewModel.onCityInputChange($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit(searchWeather)

            if geoViewModel.citySuggestLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if !geoViewModel.citySuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(geoViewModel.citySuggestions) { suggestion in
                        Button {
                            geoViewModel.onCitySuggestionChosen(suggestion)
                        } label: {
                            Text(suggestion.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
        }
    }

    private var getWeatherButton: some View {
        Button("Get weather", action: searchWeather)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(isLoading)
    }

    @ViewBuilder
    private var content: some View {
        switch weatherViewModel.currentWeather {
        case .idle:
            Text("Enter a city and tap Get weather.")
                .foregroundStyle(.secondary)

        case .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 24)

        case .success(let weather):
            CurrentWeatherContent(weather: weather)

        case .error(let message, let canRetry):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundStyle(.red)
                if canRetry {
                    Button("Retry") {
                        weatherViewModel.clearCurrentError()
                        searchWeather()
                    }
                }
            }
        }
    }

    private var isLoading: Bool {
        if case .loading = weatherViewModel.currentWeather { return true }
        return false
    }

    private func searchWeather() {
        geoViewModel.dismissSuggestions()
        weatherViewModel.refreshCurrent(
            city: geoViewModel.cityInput,
            latitude: geoViewModel.pinnedLatitude,
            longitude: geoViewModel.pinnedLongitude
        )
    }
}

private struct CurrentWeatherContent: View {
    let weather: CurrentWeather

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                WeatherIconView(iconCode: weather.iconCode, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather.cityName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(weather.description)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            MetricRow(label: "Temperature", value: formatTemperature(weather.temperature, units: weather.units))
            MetricRow(label: "Feels like", value: formatTemperature(weather.feelsLike, units: weather.units))
            MetricRow(label: "Humidity", value: "\(weather.humidityPercent)%")
            MetricRow(label: "Wind speed", value: formatWind(weather.windSpeed, units: weather.units))
        }
    }

    private func formatTemperature(_ value: Double, units: WeatherUnits) -> String {
        switch units {
        case .metric: String(format: "%.1f °C", value)
        case .imperial: String(format: "%.1f °F", value)
        }
    }

    private func formatWind(_ speed: Double, units: WeatherUnits) -> String {
        switch units {
        case .metric: String(format: "%.1f m/s", speed)
        case .imperial: String(format: "%.1f mph", speed)
        }
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(.body)
    }
}
