import CoreLocation
import XCTest
@testable import Cats_Dogs

@MainActor
final class LocationPermissionViewModelTests: XCTestCase {
    func testFetchLocationWithoutPermissionDeniesImmediatelyAndDoesNotQueryLocation() async {
        var locationQueries = 0
        let viewModel = LocationPermissionViewModel(
            authorizationStatus: { .denied },
            locationFetcher: {
                locationQueries += 1
                return CLLocation(latitude: 1, longitude: 2)
            }
        )

        viewModel.fetchLocation()
        await settle()

        XCTAssertEqual(viewModel.state, .permissionDenied)
        XCTAssertEqual(locationQueries, 0)
    }

    func testNotDeterminedCountsAsNoPermission() {
        let viewModel = LocationPermissionViewModel(authorizationStatus: { .notDetermined })

        XCTAssertFalse(viewModel.hasLocationPermission())
    }

    func testFetchLocationShowsLocatingThenResolvesCurrentLocation() async {
        let gate = Gate<CLLocation?>()
        let viewModel = LocationPermissionViewModel(
            authorizationStatus: { .authorizedWhenInUse },
            locationFetcher: { try await gate.value() }
        )

        viewModel.fetchLocation()
        XCTAssertEqual(viewModel.state, .locating)

        gate.succeed(CLLocation(latitude: 35.96, longitude: -83.92))
        await waitUntil { viewModel.state != .locating }

        XCTAssertEqual(
            viewModel.state,
            .located(SavedLocation(label: "My Location", latitude: 35.96, longitude: -83.92, isCurrentLocation: true))
        )
    }

    func testFetchLocationFailsWhenNoCoordinatesAreReturned() async {
        let viewModel = LocationPermissionViewModel(
            authorizationStatus: { .authorizedAlways },
            locationFetcher: { nil }
        )

        viewModel.fetchLocation()
        await waitUntil { viewModel.state != .locating }

        XCTAssertEqual(viewModel.state, .failed)
    }

    func testFetchLocationFailsWhenLocationLookupThrows() async {
        let viewModel = LocationPermissionViewModel(
            authorizationStatus: { .authorizedWhenInUse },
            locationFetcher: { throw CLError(.locationUnknown) }
        )

        viewModel.fetchLocation()
        await waitUntil { viewModel.state != .locating }

        XCTAssertEqual(viewModel.state, .failed)
    }

    func testOnPermissionDeniedRecordsDeniedState() {
        let viewModel = LocationPermissionViewModel(authorizationStatus: { .notDetermined })

        viewModel.onPermissionDenied()

        XCTAssertEqual(viewModel.state, .permissionDenied)
    }
}
