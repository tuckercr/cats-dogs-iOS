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
        // A single-line bar with the city tabs fixed beneath it, like Android's top app bar. A large
        // title under the tabs' inset is drawn blurred behind the scroll edge effect.
        .navigationBarTitleDisplayMode(.inline)
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
                        .contentShape(Capsule())
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
                .font(.brand(.title2))
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

    /// The hourly strip covers the next 24 hours.
    private static let hourlyStripCount = 24
    /// Landscape phones and tablets put the hero beside today's details instead of stacking
    /// everything in one stretched column.
    private static let wideLayoutMinWidth: CGFloat = 600

    @State private var contentWidth: CGFloat = 0

    private var isWide: Bool { contentWidth >= Self.wideLayoutMinWidth }

    private var forecastDays: [DayForecast] {
        forecastState.successValue ?? []
    }

    /// "Today" in the city's own date, so it matches the city-local forecast labels.
    private var todayForecast: DayForecast? {
        let todayLabel = WeatherFormatting.todayLabel(timeZone: weather.timeZone)
        return forecastDays.first.flatMap { $0.dateLabel == todayLabel ? $0 : nil }
    }

    private var upcomingDays: [DayForecast] {
        todayForecast != nil ? Array(forecastDays.dropFirst()) : forecastDays
    }

    private var currentTempC: Double { weather.units.toCelsius(weather.temperature) }

    private var mood: PetMood {
        PetMood.forConditions(conditionMain: weather.conditionMain, iconCode: weather.iconCode, temperatureC: currentTempC)
    }

    /// Nil while the forecast is loading or failed, which hides the card rather than giving advice
    /// with nothing to base it on.
    private var walkAdvice: WalkAdvice? {
        WalkAdvisor.advice(currentTempC: currentTempC, upcoming: forecastDays.flatMap(\.hourlySlots))
    }

    private var hourlySlots: [HourlySlot] {
        Array(forecastDays.flatMap(\.hourlySlots).prefix(Self.hourlyStripCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) { heroSection }
                    VStack(alignment: .leading, spacing: 12) { todaySection }
                }
            } else {
                heroSection
            }
            if !hourlySlots.isEmpty {
                SectionHeader("HOURLY")
                HourlyStrip(slots: hourlySlots)
            }
            if !isWide {
                todaySection
            }
            SectionHeader("RADAR")
            RadarCard(location: location, timeZone: weather.timeZone)
            restOfWeek
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            contentWidth = width
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        heroCard
        if let walkAdvice {
            WalkCard(advice: walkAdvice)
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        SectionHeader("TODAY")
        detailsCard
    }

    @ViewBuilder
    private var restOfWeek: some View {
        if !upcomingDays.isEmpty || forecastState == .loading || isForecastError {
            SectionHeader("REST OF WEEK")

            if !upcomingDays.isEmpty {
                // Wide screens show the days in two columns, with matching row heights, rather than
                // stretched rows.
                let columns = isWide ? 2 : 1
                Grid(alignment: .topLeading, horizontalSpacing: 24, verticalSpacing: 0) {
                    ForEach(Array(stride(from: 0, to: upcomingDays.count, by: columns)), id: \.self) { start in
                        GridRow {
                            ForEach(upcomingDays[start ..< min(start + columns, upcomingDays.count)]) { day in
                                UpcomingDayRow(day: day) {
                                    onDaySelected(day)
                                }
                            }
                            if columns == 2, start + 1 >= upcomingDays.count {
                                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
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
            VStack(spacing: 4) {
                // Kept smaller than the card so the scene doesn't dominate, especially on wide screens.
                PetScene(mood: mood)
                    .frame(maxWidth: 280)
                    .padding(.horizontal, 24)
                Text(weather.description)
                if location != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(weather.cityName)
                            .font(.brand(.title2))
                    }
                    .padding(.top, 4)
                }
                Text(WeatherFormatting.temperature(weather.temperature, units: weather.units))
                    .font(.brand(.largeTitle, weight: .bold))
                    // Baloo 2 reserves a lot of empty space above its digits; pull the number up
                    // into it so it sits close under the city name.
                    .padding(.top, -10)
                Text(
                    "\(WeatherFormatting.temperature(weather.tempMin, units: weather.units)) / \(WeatherFormatting.temperature(weather.tempMax, units: weather.units))"
                )
                Text(mood.caption())
                    .font(.brand(.headline))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            .foregroundStyle(mood.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(mood.skyColor, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(todayForecast == nil)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            MetricIconRow(
                icon: "thermometer.medium",
                label: "Feels like",
                value: WeatherFormatting.temperature(weather.feelsLike, units: weather.units)
            )
            Divider().padding(.horizontal, 16)
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
            // UV is always 0 after dark, so it only shows in the daytime (night icons end in "n").
            if !weather.iconCode.hasSuffix("n"), let uv = forecastDays.first?.hourlySlots.first?.uvIndex {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "sun.max.fill",
                    label: "UV index",
                    value: WeatherFormatting.uvIndex(uv),
                    iconTint: .brandYellow
                )
            }
            if let sunrise = weather.sunriseEpoch {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "sunrise.fill",
                    label: "Sunrise",
                    value: WeatherFormatting.epochTime(sunrise, timeZone: weather.timeZone),
                    iconTint: .brandYellow
                )
            }
            if let sunset = weather.sunsetEpoch {
                Divider().padding(.horizontal, 16)
                MetricIconRow(
                    icon: "sunset.fill",
                    label: "Sunset",
                    value: WeatherFormatting.epochTime(sunset, timeZone: weather.timeZone),
                    iconTint: .brandYellow
                )
            }
        }
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct HourlyStrip: View {
    let slots: [HourlySlot]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(slots) { slot in
                    VStack(spacing: 6) {
                        Text(slot.timeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        WeatherIconView(iconCode: slot.iconCode, size: 32)
                        Text("\(Int(slot.temperature.rounded()))°")
                            .fontWeight(.semibold)
                        PrecipChance(percent: slot.precipitationChance)
                    }
                    .padding(.horizontal, 8)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Small "raindrop N%" chip; shows nothing at 0% to avoid clutter.
private struct PrecipChance: View {
    let percent: Int

    var body: some View {
        if percent > 0 {
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                Text("\(percent)%")
                    .font(.caption)
            }
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Chance of precipitation \(percent)%")
        }
    }
}

private struct MetricIconRow: View {
    let icon: String
    let label: String
    let value: String
    var iconTint: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconTint)
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
        VStack(spacing: 0) {
            dayButton
                .frame(maxHeight: .infinity)
            Divider()
        }
    }

    private var dayButton: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                WeatherIconView(iconCode: day.iconCode, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dateLabel)
                        .fontWeight(.medium)
                    Text(day.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PrecipChance(percent: day.precipitationChance)
                }
                Spacer()
                Text(WeatherFormatting.temperature(day.tempMax, units: day.units))
                    .fontWeight(.semibold)
                Text(WeatherFormatting.temperature(day.tempMin, units: day.units))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
