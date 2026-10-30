import Foundation

/// Whether to ask for an update, from the versions set in Remote Config. Below the minimum supported
/// version the app is blocked until it's updated; below the recommended one a banner asks, and
/// "Not now" hides it for a week. Unset keys never ask. Same rules as Android's `UpdatePrompt`, with
/// separate keys per platform.
enum UpdatePrompt: Equatable {
    case none, recommended, required

    /// How long "Not now" hides the banner.
    static let snooze: TimeInterval = 7 * 24 * 60 * 60

    static func forVersion(
        _ version: String,
        minSupported: String?,
        minRecommended: String?,
        bannerDismissedAt: Date?,
        now: Date = Date()
    ) -> UpdatePrompt {
        if isOlder(version, than: minSupported) { return .required }
        guard isOlder(version, than: minRecommended) else { return .none }
        if let bannerDismissedAt, now.timeIntervalSince(bannerDismissedAt) < snooze { return .none }
        return .recommended
    }

    /// Compares number by number, so 1.10 is newer than 1.9 and 1.2 equals 1.2.0. A blank minimum
    /// is never newer.
    static func isOlder(_ version: String, than minimum: String?) -> Bool {
        guard let minimum = minimum?.trimmingCharacters(in: .whitespaces), !minimum.isEmpty else { return false }
        let mine = numbers(version)
        let wanted = numbers(minimum)
        for index in 0 ..< max(mine.count, wanted.count) {
            let a = index < mine.count ? mine[index] : 0
            let b = index < wanted.count ? wanted[index] : 0
            if a != b { return a < b }
        }
        return false
    }

    /// "1.2.3" as [1, 2, 3]; anything after the digits in a part ("3-beta") is ignored.
    private static func numbers(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
