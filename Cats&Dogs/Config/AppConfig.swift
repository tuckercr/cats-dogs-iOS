import Foundation

enum AppConfig {
    private static let secretsFileName = "Secrets"

    /// The OpenWeather key: Remote Config `openweather_api_key` when set, so a leaked key can be
    /// rotated without an update, otherwise the one built into the app. API clients read it when
    /// they're created, so a rotated key takes effect from the next launch.
    static var openWeatherApiKey: String {
        resolveOpenWeatherApiKey(remoteKey: RemoteConfigRepository.openWeatherApiKey, bundledKey: bundledOpenWeatherApiKey)
    }

    static func resolveOpenWeatherApiKey(remoteKey: String?, bundledKey: String) -> String {
        let remote = remoteKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return remote.isEmpty ? bundledKey : remote
    }

    /// OpenWeatherMap API key loaded from `Secrets.plist` (copy from `Secrets.example.plist`).
    private static var bundledOpenWeatherApiKey: String {
        guard
            let url = Bundle.main.url(forResource: secretsFileName, withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any],
            let key = plist["OWM_API_KEY"] as? String
        else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
