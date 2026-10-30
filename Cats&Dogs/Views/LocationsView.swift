import SwiftUI

struct LocationsView: View {
    @Bindable var cityListViewModel: CityListViewModel
    @Bindable var geoViewModel: GeoLocationViewModel
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                ForEach(Array(cityListViewModel.locations.enumerated()), id: \.offset) { index, location in
                    HStack {
                        if location.isCurrentLocation {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accent)
                        }
                        Text(location.label)
                        if index == cityListViewModel.locations.notificationIndex {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accent)
                                .accessibilityLabel("Notifications")
                        }
                        Spacer()
                    }
                    // The last city stays: the app always has one to show.
                    .deleteDisabled(cityListViewModel.locations.count <= 1)
                }
                // The standard delete: swipe left, or Edit and the red minus.
                .onDelete { offsets in
                    guard let index = offsets.first, cityListViewModel.locations.count > 1 else { return }
                    cityListViewModel.removeLocation(at: index)
                }
                .onMove { source, destination in
                    cityListViewModel.reorderLocations(from: source, to: destination)
                }
            } footer: {
                Label("Notifications are for My Location, otherwise the top city.", systemImage: "bell.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
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
                onAddMyLocation: { cityListViewModel.addLocation($0) },
                onDismiss: {
                    geoViewModel.reset()
                    showAddSheet = false
                }
            )
        }
    }

    private func addCityFromSheet() {
        guard let location = geoViewModel.locationToAdd else { return }
        cityListViewModel.addLocation(location)
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
