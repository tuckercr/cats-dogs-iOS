import SwiftUI

struct CurrentWeatherView: View {
    @Bindable var cityListViewModel: CityListViewModel
    @Bindable var geoViewModel: GeoLocationViewModel
    @Bindable var weatherViewModel: WeatherForecastViewModel
    let onOpenForecast: () -> Void

    @State private var showAddSheet = false
    @State private var selectedDay: DayForecast?

    private var forecastDays: [DayForecast] {
        if case .success(let days) = weatherViewModel.forecast { return days }
        return []
    }

    var body: some View {
        Group {
            if cityListViewModel.locations.isEmpty {
                emptyState
            } else {
                weatherContent
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a city")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if cityListViewModel.locations.count >= 2 {
                cityTabs
            }
        }
        .onChange(of: cityListViewModel.activeLocation?.label) { _, _ in
            refreshActiveLocation()
        }
        .task {
            refreshActiveLocation()
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet(
                savedLocations: cityListViewModel.locations,
                geoViewModel: geoViewModel,
                onAddCity: addCityFromSheet,
                onRemoveSaved: { index in
                    cityListViewModel.removeLocation(at: index)
                },
                onDismiss: {
                    geoViewModel.reset()
                    showAddSheet = false
                }
            )
        }
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(day: day)
        }
    }

    private var navigationTitle: String {
        cityListViewModel.activeLocation?.label ?? "Cats & Dogs"
    }

    private var cityTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(cityListViewModel.locations.enumerated()), id: \.offset) { index, location in
                    Button {
                        cityListViewModel.setActiveIndex(index)
                    } label: {
                        HStack(spacing: 4) {
                            if location.isCurrentLocation {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                            }
                            Text(location.label)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            index == cityListViewModel.activeIndex
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove", role: .destructive) {
                            cityListViewModel.removeLocation(at: index)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor.opacity(0.4))
            Text("No cities added yet")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text("Tap the + button to add your first city and get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Add city", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var weatherContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch weatherViewModel.currentWeather {
                case .idle, .loading:
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 48)
                        Spacer()
                    }

                case .success(let weather):
                    CurrentWeatherContent(
                        weather: weather,
                        forecastDays: forecastDays,
                        onOpenForecast: onOpenForecast,
                        onDaySelected: { selectedDay = $0 }
                    )

                case .error(let message, let canRetry):
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message)
                            .foregroundStyle(.red)
                        if canRetry {
                            Button("Retry", action: refreshActiveLocation)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func refreshActiveLocation() {
        guard let location = cityListViewModel.activeLocation else { return }
        weatherViewModel.refreshCurrent(location: location)
        weatherViewModel.refreshForecast(location: location)
    }

    private func addCityFromSheet() {
        if let suggestion = geoViewModel.selectedSuggestion {
            cityListViewModel.addLocation(
                SavedLocation(
                    label: suggestion.label,
                    latitude: suggestion.weatherLat,
                    longitude: suggestion.weatherLon
                )
            )
        } else {
            let trimmed = geoViewModel.cityInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            cityListViewModel.addLocation(
                SavedLocation(label: trimmed, latitude: nil, longitude: nil)
            )
        }
        geoViewModel.reset()
        showAddSheet = false
    }
}

private struct CurrentWeatherContent: View {
    let weather: CurrentWeather
    let forecastDays: [DayForecast]
    let onOpenForecast: () -> Void
    let onDaySelected: (DayForecast) -> Void

    private var todayLabel: String {
        WeatherFormatting.todayLabel()
    }

    private var todayForecast: DayForecast? {
        forecastDays.first { $0.dateLabel == todayLabel }
    }

    private var upcomingDays: [DayForecast] {
        if todayForecast != nil {
            return Array(forecastDays.dropFirst())
        }
        return forecastDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroCard
            detailsCard

            if !upcomingDays.isEmpty {
                Text("UPCOMING")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(upcomingDays) { day in
                    UpcomingDayRow(day: day) {
                        onDaySelected(day)
                    }
                }
            }

            Button(action: onOpenForecast) {
                Label("View 5-day forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var heroCard: some View {
        Button {
            if let today = todayForecast {
                onDaySelected(today)
            }
        } label: {
            VStack(spacing: 8) {
                WeatherIconView(iconCode: weather.iconCode, size: 88)
                Text(weather.description)
                    .foregroundStyle(.secondary)
                Text(WeatherFormatting.temperature(weather.temperature, units: weather.units))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(
                    "\(WeatherFormatting.temperature(weather.tempMin, units: weather.units)) / \(WeatherFormatting.temperature(weather.tempMax, units: weather.units))"
                )
                .foregroundStyle(.secondary)
                Text("Feels like \(WeatherFormatting.temperature(weather.feelsLike, units: weather.units))")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(todayForecast == nil)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            MetricIconRow(
                icon: "drop.fill",
                label: "Humidity",
                value: "\(weather.humidityPercent)%"
            )
            Divider().padding(.horizontal, 16)
            MetricIconRow(
                icon: "wind",
                label: "Wind",
                value: "\(WeatherFormatting.wind(weather.windSpeed, units: weather.units))  \(WeatherFormatting.windDirection(weather.windDeg))"
            )
            Divider().padding(.horizontal, 16)
            MetricIconRow(
                icon: "gauge.with.dots.needle.33percent",
                label: "Pressure",
                value: WeatherFormatting.pressure(weather.pressureHpa)
            )
            if let visibility = weather.visibilityMeters {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "eye",
                    label: "Visibility",
                    value: WeatherFormatting.visibility(visibility)
                )
            }
            Divider().padding(.horizontal, 16)
            MetricIconRow(
                icon: "cloud.fill",
                label: "Cloud cover",
                value: "\(weather.cloudPercent)%"
            )
        }
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetricIconRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(label)
            Spacer()
            Text(value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct UpcomingDayRow: View {
    let day: DayForecast
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                WeatherIconView(iconCode: day.iconCode, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dateLabel)
                        .fontWeight(.medium)
                    Text(day.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(WeatherFormatting.temperature(day.tempMax, units: day.units))
                    .fontWeight(.semibold)
                Text(WeatherFormatting.temperature(day.tempMin, units: day.units))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        Divider()
    }
}
