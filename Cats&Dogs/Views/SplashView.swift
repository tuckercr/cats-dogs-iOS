import SwiftUI

/// Branded splash screen shown briefly on every launch before the main content appears.
///
/// Mirrors the Android splash: blue brand-colour background, centred app icon,
/// and the horizontal brand logo at the bottom — identical to the Android SplashScreen API layout.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.118, green: 0.533, blue: 0.898)
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
