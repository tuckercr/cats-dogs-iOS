import SwiftUI
import UIKit

/// Shared brand styling, matching the Android app's theme (`ui/theme/Color.kt`, `Type.kt`).
/// Colours live in the asset catalog: AccentColor is the brand blue, and BrandYellow (the mascot's
/// gold, generated as `Color.brandYellow`) is used for sun-related icons.
extension Font {
    /// Baloo 2, the rounded face that echoes the "Cats & Dogs" wordmark. Used for display and title
    /// text only; body copy stays on the system font. Scales with Dynamic Type via `style`.
    static func brand(_ style: Font.TextStyle, weight: BrandWeight = .semibold) -> Font {
        .custom(weight.postScriptName, size: BrandWeight.pointSize(for: style), relativeTo: style)
    }

    enum BrandWeight {
        case medium
        case semibold
        case bold

        var postScriptName: String {
            switch self {
            case .medium: "Baloo2-Medium"
            case .semibold: "Baloo2-SemiBold"
            case .bold: "Baloo2-Bold"
            }
        }

        /// Default (Large) Dynamic Type sizes, so Baloo 2 lines up with the system styles it replaces.
        static func pointSize(for style: Font.TextStyle) -> CGFloat {
            switch style {
            case .largeTitle: 34
            case .title: 28
            case .title2: 22
            case .title3: 20
            case .headline, .body: 17
            case .callout: 16
            case .subheadline: 15
            case .footnote: 13
            case .caption: 12
            case .caption2: 11
            default: 17
            }
        }
    }
}

enum BrandAppearance {
    /// Navigation bar titles use Baloo 2, like the Android top app bar.
    @MainActor
    static func apply() {
        let appearance = UINavigationBar.appearance()
        if let large = UIFont(name: Font.BrandWeight.bold.postScriptName, size: 34) {
            appearance.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
        if let inline = UIFont(name: Font.BrandWeight.semibold.postScriptName, size: 19) {
            appearance.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline)]
        }
    }
}
