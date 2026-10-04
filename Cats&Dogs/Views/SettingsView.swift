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
            Section("Units") {
                ForEach(UnitOverride.allCases, id: \.self) { option in
                    Button {
                        settingsViewModel.setUnitOverride(option)
                    } label: {
                        HStack {
                            Text(unitLabel(for: option))
                            Spacer()
                            if settingsViewModel.unitOverride == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        // A plain button only hit-tests what it draws; make the whole row tappable.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Location") {
                permissionRow(
                    status: settingsViewModel.locationPermission,
                    grantedText: "Location access granted",
                    requestTitle: "Allow location access",
                    openSettingsTitle: "Open Settings to enable location",
                    settingsURL: UIApplication.openSettingsURLString,
                    onRequest: { locationViewModel.requestPermission() }
                )
            }

            Section("Notifications") {
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
            }

            Section("Locations") {
                Button("Manage locations", action: onOpenLocations)
            }

            Section("Cache") {
                Button("Clear cached weather") {
                    settingsViewModel.clearCache()
                    showCacheCleared = true
                }
            }

            Section("About") {
                Button("Weather data by OpenWeather") {
                    openURL(URL(string: "https://openweathermap.org/")!)
                }
                // Open-Meteo's free API is CC BY 4.0, which requires this credit.
                Button("Forecast data by Open-Meteo.com") {
                    openURL(URL(string: "https://open-meteo.com")!)
                }
                Button("Privacy policy") {
                    openURL(URL(string: "https://fangjet.com/privacy-policy")!)
                }
            }
        }
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

    private func unitLabel(for override: UnitOverride) -> String {
        switch override {
        case .system: "Use system setting"
        case .metric: "Metric (°C)"
        case .imperial: "Imperial (°F)"
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
                .foregroundStyle(.secondary)
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
