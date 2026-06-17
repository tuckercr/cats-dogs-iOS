import CoreLocation
import Foundation
import Observation

enum LocationFetchState: Equatable {
    case idle
    case locating
    case located(SavedLocation)
    case permissionDenied
    case failed
}

@MainActor
@Observable
final class LocationPermissionViewModel: NSObject, CLLocationManagerDelegate {
    private(set) var state: LocationFetchState = .idle

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Error>?
    private var awaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func hasLocationPermission() -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func requestPermission() {
        awaitingAuthorization = true
        manager.requestWhenInUseAuthorization()
    }

    func onPermissionDenied() {
        state = .permissionDenied
    }

    func fetchLocation() {
        guard hasLocationPermission() else {
            state = .permissionDenied
            return
        }
        state = .locating
        Task {
            do {
                let location = try await requestLocation()
                if let location {
                    state = .located(
                        SavedLocation(
                            label: "My Location",
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            isCurrentLocation: true
                        )
                    )
                } else {
                    state = .failed
                }
            } catch {
                state = .failed
            }
        }
    }

    private func requestLocation() async throws -> CLLocation? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if awaitingAuthorization {
                    awaitingAuthorization = false
                    fetchLocation()
                }
            case .denied, .restricted:
                if awaitingAuthorization {
                    awaitingAuthorization = false
                    state = .permissionDenied
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.first)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
