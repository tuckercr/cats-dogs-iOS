import SwiftUI

struct AddCitySheet: View {
    let savedLocations: [SavedLocation]
    @Bindable var geoViewModel: GeoLocationViewModel
    let onAddCity: () -> Void
    let onRemoveSaved: (Int) -> Void
    /// Adds the device's location as "My Location", offered while it isn't saved and access is on.
    let onAddMyLocation: (SavedLocation) -> Void
    let onDismiss: () -> Void

    @State private var locationViewModel = LocationPermissionViewModel()

    private var canAddMyLocation: Bool {
        !savedLocations.contains(where: \.isCurrentLocation) && locationViewModel.hasLocationPermission()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !savedLocations.isEmpty {
                        Text("SAVED CITIES")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        ForEach(Array(savedLocations.enumerated()), id: \.offset) { index, location in
                            HStack {
                                if location.isCurrentLocation {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accent)
                                }
                                Text(location.label)
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) {
                                    onRemoveSaved(index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                        Divider()
                    }

                    if canAddMyLocation {
                        Button {
                            locationViewModel.fetchLocation()
                        } label: {
                            HStack {
                                if locationViewModel.state == .locating {
                                    ProgressView()
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text("Add My Location")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(locationViewModel.state == .locating)
                    }

                    Text("ADD A NEW CITY")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)

                    TextField("City", text: Binding(
                        get: { geoViewModel.cityInput },
                        set: { geoViewModel.onCityInputChange($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                    if geoViewModel.citySuggestLoading {
                        ProgressView()
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
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Add city", action: onAddCity)
                        .accentButtonStyle()
                        .frame(maxWidth: .infinity)
                        .disabled(
                            geoViewModel.cityInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && geoViewModel.selectedSuggestion == nil
                        )

                    Button("Cancel", action: onDismiss)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
            .navigationTitle("Manage cities")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .onChange(of: locationViewModel.state) { _, state in
            if case .located(let location) = state {
                onAddMyLocation(location)
                onDismiss()
            }
        }
    }
}
