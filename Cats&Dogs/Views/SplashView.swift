import SwiftUI

/// Branded splash screen shown briefly on every launch before the main content appears.
///
/// Mirrors the Android splash: blue brand-colour background, centred app icon,
/// and the horizontal brand logo at the bottom — identical to the Android SplashScreen API layout.
struct SplashView: View {
    var body: some View {
        ZStack {
            // The same blue as the system launch screen (UILaunchScreen), so there's no colour jump
            // when this view takes over from it.
            Color.launchBackground
                .ignoresSafeArea()

            VStack {
                Spacer()

                Image("LaunchSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)

                Spacer()

                Image("BrandImage")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    SplashView()
}
