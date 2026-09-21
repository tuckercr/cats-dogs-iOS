import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var settingsViewModel: SettingsViewModel
    let onOpenLocations: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var locationGranted = false
    @State private var notificationGranted = false
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
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Location") {
                if locationGranted {
                    Text("Location access granted")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Open Settings to enable location") {
                        openAppSettings()
                    }
                }
            }

            Section("Notifications") {
                if notificationGranted {
                    Text("Notifications enabled")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Open Settings to enable notifications") {
                        openAppSettings()
                    }
                }
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
                Button("Privacy policy") {
                    openURL(URL(string: "https://fangjet.com/privacy-policy")!)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPermissionState() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPermissionState() }
            }
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

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func refreshPermissionState() async {
        locationGranted = LocationPermissionViewModel().hasLocationPermission()
        let status = await WeatherNotificationScheduler.shared.authorizationStatus()
        notificationGranted = status == .authorized || status == .provisional
    }
}

#Preview {
    NavigationStack {
        SettingsView(settingsViewModel: SettingsViewModel(), onOpenLocations: {})
    }
}
