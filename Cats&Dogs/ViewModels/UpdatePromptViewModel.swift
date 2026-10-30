import Foundation
import Observation

/// Which update prompt to show, if any, and where the Update button goes.
@MainActor
@Observable
final class UpdatePromptViewModel {
    private(set) var prompt: UpdatePrompt = .none
    /// Nil until the App Store link is set in Remote Config, which hides the Update button.
    private(set) var storeURL: URL?

    private let preferences: PreferencesStore
    private let version: String
    private let minSupported: () -> String?
    private let minRecommended: () -> String?
    private let appStoreURL: () -> URL?
    private let now: () -> Date

    init(
        preferences: PreferencesStore? = nil,
        version: String? = nil,
        minSupported: (() -> String?)? = nil,
        minRecommended: (() -> String?)? = nil,
        appStoreURL: (() -> URL?)? = nil,
        now: (() -> Date)? = nil
    ) {
        self.preferences = preferences ?? .shared
        self.version = version ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        self.minSupported = minSupported ?? { RemoteConfigRepository.shared.iosMinSupportedVersion }
        self.minRecommended = minRecommended ?? { RemoteConfigRepository.shared.iosMinRecommendedVersion }
        self.appStoreURL = appStoreURL ?? { RemoteConfigRepository.shared.iosAppStoreURL }
        self.now = now ?? { Date() }
        refresh()
    }

    /// Reads Remote Config again: on launch, and each time the app comes back, since newly fetched
    /// values only apply from the next read.
    func refresh() {
        prompt = UpdatePrompt.forVersion(
            version,
            minSupported: minSupported(),
            minRecommended: minRecommended(),
            bannerDismissedAt: preferences.updateBannerDismissedAt,
            now: now()
        )
        storeURL = appStoreURL()
        #if DEBUG
        // Launch with -updatePrompt required (or recommended) to see a prompt without Remote Config.
        switch UserDefaults.standard.string(forKey: "updatePrompt") {
        case "required": prompt = .required
        case "recommended": prompt = .recommended
        default: break
        }
        #endif
    }

    /// "Not now" on the banner.
    func dismissBanner() {
        preferences.setUpdateBannerDismissedAt(now())
        refresh()
    }
}
