import SwiftUI

struct LocationsView: View {
    @Bindable var cityListViewModel: CityListViewModel
    @Bindable var geoViewModel: GeoLocationViewModel
    @State private var showAddSheet = false

    var body: some View {
        List {
            ForEach(Array(cityListViewModel.locations.enumerated()), id: \.offset) { index, location in
                HStack {
                    if location.isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(index == cityListViewModel.activeIndex ? "\(location.label) (Active)" : location.label)
                    Spacer()
                    if index != cityListViewModel.activeIndex {
                        Button("Set active") {
                            cityListViewModel.setActiveIndex(index)
                        }
                        .font(.caption)
                    }
                }
                // The active city is highlighted like Android's Manage Locations list.
                .listRowBackground(
                    index == cityListViewModel.activeIndex
                        ? Color.surfaceVariant
                        : Color(.secondarySystemGroupedBackground)
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if cityListViewModel.locations.count > 1 {
                        Button("Delete", role: .destructive) {
                            cityListViewModel.removeLocation(at: index)
                        }
                    }
                }
            }
            .onMove { source, destination in
                cityListViewModel.reorderLocations(from: source, to: destination)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brandSurface)
        .navigationTitle("Manage Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add location")
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCitySheet(
                savedLocations: cityListViewModel.locations,
                geoViewModel: geoViewModel,
                onAddCity: {
                    addCityFromSheet()
                    showAddSheet = false
                },
                onRemoveSaved: { index in
                    cityListViewModel.removeLocation(at: index)
                },
                onDismiss: {
                    geoViewModel.reset()
                    showAddSheet = false
                }
            )
        }
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
    }
}

#Preview {
    NavigationStack {
        LocationsView(
            cityListViewModel: CityListViewModel(),
            geoViewModel: GeoLocationViewModel()
        )
    }
}
