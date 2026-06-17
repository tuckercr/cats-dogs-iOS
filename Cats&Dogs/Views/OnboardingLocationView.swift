import SwiftUI

struct OnboardingLocationView: View {
    let onLocationResolved: (SavedLocation) -> Void
    let onSkip: () -> Void

    @State private var viewModel = LocationPermissionViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 112, height: 112)
                if viewModel.state == .locating {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text("Use your location?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if viewModel.state != .locating {
                Button("Use my location", action: requestLocation)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Enter a city manually", action: onSkip)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(32)
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
            "Allow Cats & Dogs to use your device location to show local weather automatically."
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
