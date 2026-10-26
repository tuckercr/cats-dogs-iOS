import SwiftUI

/// Who lives with the user. Only a dog makes the "Best walk time" card worth showing.
enum Household: CaseIterable {
    case dog
    case cat
    case both
    case neither

    var label: String {
        switch self {
        case .dog: "A dog"
        case .cat: "A cat"
        case .both: "A dog and a cat"
        case .neither: "No pets"
        }
    }

    var hasDog: Bool { self == .dog || self == .both }
}

/// Onboarding step after the welcome screen. The answer sets the "Best walk time" switch in
/// Settings, so a home without a dog never sees the walk card. Same as Android.
struct OnboardingHouseholdView: View {
    let onChosen: (Household) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PetScene(mood: .cloudy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(PetMood.cloudy.skyColor, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)

                Text("Who's at home?")
                    .font(.brand(.title2))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)

                Text("If there's a dog, Sunny will suggest the best time for a walk. You can change this later in Settings.")
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(Household.allCases, id: \.self) { household in
                        Button {
                            onChosen(household)
                        } label: {
                            Text(household.label)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Centres the content when it fits, as the other onboarding screens' spacers do.
        .defaultScrollAnchor(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface)
    }
}

#Preview {
    OnboardingHouseholdView(onChosen: { _ in })
}
