import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var settingsViewModel: SettingsViewModel
    let onOpenLocations: () -> Void
    let onLocationResolved: (SavedLocation) -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var locationViewModel = LocationPermissionViewModel()
    @State private var showCacheCleared = false

    var body: some View {
        List {
            Section {
                ForEach(UnitOverride.allCases, id: \.self) { option in
                    Button {
                        settingsViewModel.setUnitOverride(option)
                    } label: {
                        HStack {
                            Text(unitLabel(for: option))
                            Spacer()
                            if settingsViewModel.unitOverride == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                            }
                        }
                        // A plain button only hit-tests what it draws; make the whole row tappable.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // The checkmark is visual only; VoiceOver reads "Selected" from this trait.
                    .accessibilityAddTraits(settingsViewModel.unitOverride == option ? .isSelected : [])
                }
            } header: {
                sectionHeader("Units")
            }

            Section {
                // The walk card and the Paw check tile, for people without a dog to turn off.
                switchRow(
                    "Dog walking",
                    summary: "Best walk time and Paw check",
                    isOn: settingsViewModel.showWalkCard,
                    set: settingsViewModel.setShowWalkCard
                )
            } header: {
                sectionHeader("Main screen")
            }

            Section {
                permissionRow(
                    status: settingsViewModel.locationPermission,
                    grantedText: "Location access granted",
                    requestTitle: "Allow location access",
                    openSettingsTitle: "Open Settings to enable location",
                    settingsURL: UIApplication.openSettingsURLString,
                    onRequest: { locationViewModel.requestPermission() }
                )
            } header: {
                sectionHeader("Location")
            }

            Section {
                // Once allowed, the switches below say it all.
                if settingsViewModel.notificationPermission != .granted {
                    permissionRow(
                        status: settingsViewModel.notificationPermission,
                        grantedText: "Notifications enabled",
                        requestTitle: "Allow notifications",
                        openSettingsTitle: "Open Settings to enable notifications",
                        // Lands directly on this app's notification settings rather than its general page.
                        settingsURL: UIApplication.openNotificationSettingsURLString,
                        onRequest: {
                            Task { await settingsViewModel.requestNotificationPermission() }
                        }
                    )
                } else {
                    switchRow(
                        "Morning briefing",
                        summary: "Today's weather each morning",
                        isOn: settingsViewModel.notifyMorningBriefing,
                        set: settingsViewModel.setNotifyMorningBriefing
                    )
                    switchRow(
                        "Walk time",
                        summary: "A nudge at the day's best time for a walk",
                        isOn: settingsViewModel.notifyWalkTime,
                        set: settingsViewModel.setNotifyWalkTime
                    )
                    switchRow(
                        "Rain alerts",
                        summary: "When rain or snow is about to start",
                        isOn: settingsViewModel.notifyRain,
                        set: settingsViewModel.setNotifyRain
                    )
                }
            } header: {
                sectionHeader("Notifications")
            }

            Section {
                Button("Manage locations", action: onOpenLocations)
            } header: {
                sectionHeader("Locations")
            }

            Section {
                Button("Clear cached weather") {
                    settingsViewModel.clearCache()
                    showCacheCleared = true
                }
            } header: {
                sectionHeader("Cache")
            }

            Section {
                switchRow(
                    "Share usage statistics",
                    isOn: settingsViewModel.shareUsageStatistics,
                    set: settingsViewModel.setShareUsageStatistics
                )
            } header: {
                sectionHeader("Privacy")
            } footer: {
                Text("Anonymous counts of which features get used, to help improve Sunny & Misty. Never your location.")
                    .foregroundStyle(Color.secondaryText)
            }

            Section {
                Button("Weather data by OpenWeather") {
                    openURL(URL(string: "https://openweathermap.org/")!)
                }
                // Open-Meteo's free API is CC BY 4.0, which requires this credit.
                Button("Forecast data by Open-Meteo.com") {
                    openURL(URL(string: "https://open-meteo.com")!)
                }
                Button("Privacy policy") {
                    openURL(URL(string: "https://sunnyandmisty.com/privacy")!)
                }
            } header: {
                sectionHeader("About")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brandSurface)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await settingsViewModel.refreshPermissions() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await settingsViewModel.refreshPermissions() }
            }
        }
        .onChange(of: locationViewModel.state) { _, state in
            // Location is only useful as a saved city, so a grant made here adds it like onboarding does.
            if case .located(let location) = state {
                onLocationResolved(location)
            }
            Task { await settingsViewModel.refreshPermissions() }
        }
        .alert("Cache cleared", isPresented: $showCacheCleared) {
            Button("OK", role: .cancel) {}
        }
    }

    /// The system's header grey is only about 3.3:1 on the brand surface; this one is 8.8:1.
    private func sectionHeader(_ title: String) -> some View {
        Text(title).foregroundStyle(Color.secondaryText)
    }

    private func unitLabel(for override: UnitOverride) -> String {
        switch override {
        case .system: "Use system setting"
        case .metric: "Metric (°C)"
        case .imperial: "Imperial (°F)"
        }
    }

    /// Takes the value rather than reading it inside the binding, so the body observes it and the
    /// switch redraws when it changes.
    private func switchRow(
        _ title: String,
        summary: String? = nil,
        isOn: Bool,
        set: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        status: PermissionStatus,
        grantedText: String,
        requestTitle: String,
        openSettingsTitle: String,
        settingsURL: String,
        onRequest: @escaping () -> Void
    ) -> some View {
        switch status {
        case .granted:
            Text(grantedText)
                .foregroundStyle(Color.secondaryText)
        case .notDetermined:
            // iOS has no Settings entry for a permission the app has never asked for.
            Button(requestTitle, action: onRequest)
        case .denied:
            Button(openSettingsTitle) {
                openSystemSettings(settingsURL)
            }
        }
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        SettingsView(settingsViewModel: SettingsViewModel(), onOpenLocations: {}, onLocationResolved: { _ in })
    }
}

