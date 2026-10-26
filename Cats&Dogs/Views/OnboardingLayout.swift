import SwiftUI

/// The frame shared by the onboarding screens: centred when the content fits, and scrolling from the
/// top when it doesn't (the largest text sizes, small or landscape screens). Same as Android's
/// `OnboardingLayout`.
struct OnboardingLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            column
            ScrollView { column }
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface)
    }

    private var column: some View {
        VStack(spacing: 12) { content }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
    }
}
