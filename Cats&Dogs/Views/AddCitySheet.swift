import SwiftUI

struct AddCitySheet: View {
    let savedLocations: [SavedLocation]
    @Bindable var geoViewModel: GeoLocationViewModel
    let onAddCity: () -> Void
    let onRemoveSaved: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !savedLocations.isEmpty {
                        Text("SAVED CITIES")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(savedLocations.enumerated()), id: \.offset) { index, location in
                            HStack {
                                if location.isCurrentLocation {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
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

                    Text("ADD A NEW CITY")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Add city", action: onAddCity)
                        .buttonStyle(.borderedProminent)
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
    }
}
