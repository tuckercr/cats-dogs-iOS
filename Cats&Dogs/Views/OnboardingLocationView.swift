import SwiftUI

struct OnboardingLocationView: View {
    let onLocationResolved: (SavedLocation) -> Void
    let onSkip: () -> Void

    @State private var viewModel = LocationPermissionViewModel()

    var body: some View {
        OnboardingLayout {
            ZStack {
                Circle()
                    .fill(Color.primaryContainer)
                    .frame(width: 112, height: 112)
                if viewModel.state == .locating {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accent)
                }
            }

            Text("Use your location?")
                .font(.brand(.title2))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            if viewModel.state != .locating {
                Button(action: requestLocation) {
                    Text("Use my location").frame(maxWidth: .infinity)
                }
                .accentButtonStyle()
                .controlSize(.large)
                .padding(.top, 36)

                Button(action: onSkip) {
                    Text("Enter a city manually").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .located(let location) = newState {
                onLocationResolved(location)
            }
        }
    }

    private var bodyText: String {
        switch viewModel.state {
        case .permissionDenied:
            "Location access was denied. You can still add cities manually."
        case .failed:
            "Could not determine your location. You can still add cities manually."
        default:
            "Misty likes to know which window she's looking out of. Allow your location to see the weather where you are."
        }
    }

    private func requestLocation() {
        if viewModel.hasLocationPermission() {
            viewModel.fetchLocation()
        } else {
            viewModel.requestPermission()
        }
    }
}

#Preview {
    OnboardingLocationView(onLocationResolved: { _ in }, onSkip: {})
}
