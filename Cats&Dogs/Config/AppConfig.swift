import Foundation

enum AppConfig {
    private static let secretsFileName = "Secrets"

    /// OpenWeatherMap API key loaded from `Secrets.plist` (copy from `Secrets.example.plist`).
    static var openWeatherApiKey: String {
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
