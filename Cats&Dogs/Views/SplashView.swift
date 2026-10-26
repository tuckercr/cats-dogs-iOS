import SwiftUI

/// Branded splash screen shown briefly on every launch before the main content appears.
///
/// Mirrors the Android splash: blue brand-colour background, centred app icon,
/// and the horizontal brand logo at the bottom, like the Android SplashScreen API layout.
struct SplashView: View {
    /// The system launch screen (UILaunchScreen in Info.plist) draws LaunchSplash at its natural
    /// size, 200 pt, centred on the screen. The icon here matches it in size and place, so the
    /// handover from the launch screen to this view doesn't move anything.
    static let iconSize: CGFloat = 200

    var body: some View {
        ZStack {
            Color.launchBackground

            Image("LaunchSplash")
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Image("BrandImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240)
                .padding(.bottom, 48)
                .accessibilityLabel("Sunny & Misty")
        }
    }
}

#Preview {
    SplashView()
}
