import SwiftUI

struct CurrentWeatherView: View {
    @Bindable var cityListViewModel: CityListViewModel
    @Bindable var geoViewModel: GeoLocationViewModel
    @Bindable var weatherViewModel: WeatherForecastViewModel
    let unitOverride: UnitOverride
    let onOpenSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var showAddSheet = false
    @State private var selectedDay: DayForecast?
    @State private var rescheduleTask: Task<Void, Never>?

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
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Open settings")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if cityListViewModel.locations.count >= 2 {
                cityTabs
            }
        }
        .onChange(of: cityListViewModel.activeLocation?.cacheKey) { _, _ in
            refreshActiveLocation()
            // Also covers removing the last city, which must clear its notifications.
            rescheduleNotificationsSoon()
        }
        .onChange(of: unitOverride) { _, _ in
            // Cached data is in the old units, so this has to be a real refetch.
            refreshActiveLocation()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                backgroundRefreshActiveLocation()
            }
        }
        .onChange(of: weatherViewModel.currentWeather) { _, state in
            if case .success = state { rescheduleNotificationsSoon() }
        }
        .onChange(of: weatherViewModel.forecast) { _, state in
            if case .success = state { rescheduleNotificationsSoon() }
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
                        forecastState: weatherViewModel.forecast,
                        location: cityListViewModel.activeLocation,
                        onDaySelected: { selectedDay = $0 },
                        onForecastRetry: refreshActiveLocation
                    )

                case .error(let errorKey, let canRetry):
                    VStack(alignment: .leading, spacing: 8) {
                        Text(WeatherErrorMessages.message(for: errorKey))
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
        .refreshable {
            refreshActiveLocation()
        }
        .overlay(alignment: .top) {
            if weatherViewModel.isRefreshing {
                ProgressView()
                    .padding(.top, 8)
            }
        }
    }

    private func refreshActiveLocation() {
        guard let location = cityListViewModel.activeLocation else { return }
        weatherViewModel.refreshCurrent(location: location)
        weatherViewModel.refreshForecast(location: location)
    }

    /// Notification text is built from the cache, so reschedule once fresh data has landed. One
    /// refresh changes state up to four times (cached then fresh, for current and forecast), so the
    /// calls are coalesced into a single run.
    private func rescheduleNotificationsSoon() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await WeatherNotificationScheduler.shared.scheduleDailyNotifications()
        }
    }

    private func backgroundRefreshActiveLocation() {
        guard let location = cityListViewModel.activeLocation else { return }
        weatherViewModel.backgroundRefreshCurrent(location: location)
        weatherViewModel.backgroundRefreshForecast(location: location)
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
    let forecastState: LoadingState<[DayForecast]>
    let location: SavedLocation?
    let onDaySelected: (DayForecast) -> Void
    let onForecastRetry: () -> Void

    private var todayLabel: String {
        WeatherFormatting.todayLabel(timeZone: weather.timeZone)
    }

    private var forecastDays: [DayForecast] {
        if case .success(let days) = forecastState { return days }
        return []
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
            RadarCard(location: location, timeZone: weather.timeZone)

            if !upcomingDays.isEmpty || forecastState == .loading || isForecastError {
                Text("UPCOMING")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                if !upcomingDays.isEmpty {
                    ForEach(upcomingDays) { day in
                        UpcomingDayRow(day: day) {
                            onDaySelected(day)
                        }
                    }
                } else if forecastState == .loading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 24)
                        Spacer()
                    }
                } else if case .error(let errorKey, let canRetry) = forecastState {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(WeatherErrorMessages.message(for: errorKey))
                            .foregroundStyle(.red)
                        if canRetry {
                            Button("Retry", action: onForecastRetry)
                        }
                    }
                }
            }
        }
    }

    private var isForecastError: Bool {
        if case .error = forecastState { return true }
        return false
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
                if location != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(weather.cityName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
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
            if let sunrise = weather.sunriseEpoch {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "sunrise.fill",
                    label: "Sunrise",
                    value: WeatherFormatting.epochTime(sunrise, timeZone: weather.timeZone)
                )
            }
            if let sunset = weather.sunsetEpoch {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "sunset.fill",
                    label: "Sunset",
                    value: WeatherFormatting.epochTime(sunset, timeZone: weather.timeZone)
                )
            }
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
