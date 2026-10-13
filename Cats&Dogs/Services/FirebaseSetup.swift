import FirebaseCore
import Foundation

/// Firebase is optional, like on Android: without `GoogleService-Info.plist` in the app bundle it
/// stays unconfigured and analytics and Remote Config fall back to doing nothing / local defaults.
@MainActor
enum FirebaseSetup {
    static var isConfigured: Bool { FirebaseApp.app() != nil }

    static func configureIfAvailable() {
        // `FirebaseApp.configure()` crashes without the plist, so check for it first.
        guard !isConfigured,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
              // Unit tests run inside the app; keep their events out of the real project.
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        FirebaseApp.configure()
    }
}
