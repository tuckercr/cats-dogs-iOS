import SwiftUI

/// A weather condition icon, bundled with the app and drawn in the pet scene's style. Every shape
/// has the pets' navy outline, so the white clouds hold up on the light cards, and the fills carry
/// them on the dark ones.
struct WeatherIconView: View {
    let iconCode: String
    let size: CGFloat
    /// What VoiceOver reads, e.g. "Light rain". Nil where text beside the icon already says it.
    var description: String? = nil

    var body: some View {
        if let description {
            image.accessibilityLabel(description)
        } else {
            // Unlabelled, VoiceOver would read the asset name ("wx 01d").
            image.accessibilityHidden(true)
        }
    }

    private var image: some View {
        Image(Self.assetName(for: iconCode))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    /// Maps an OpenWeatherMap icon code ("01d", "10n"…; Open-Meteo's WMO codes are mapped onto the
    /// same set) to its asset. Only clear, few clouds and rain look different at night.
    static func assetName(for iconCode: String) -> String {
        let night = iconCode.hasSuffix("n")
        switch iconCode.prefix(2) {
        case "01": return night ? "wx_01n" : "wx_01d"
        case "02": return night ? "wx_02n" : "wx_02d"
        case "03": return "wx_03d"
        case "04": return "wx_04d"
        case "09": return "wx_09d"
        case "10": return night ? "wx_10n" : "wx_10d"
        case "11": return "wx_11d"
        case "13": return "wx_13d"
        case "50": return "wx_50d"
        default: return "wx_03d"
        }
    }
}
