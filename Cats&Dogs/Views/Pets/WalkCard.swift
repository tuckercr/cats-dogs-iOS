import SwiftUI

/// "Best walk time" card: when to take the dog out, with a quick rating chip.
struct WalkCard: View {
    let advice: WalkAdvice

    private var detail: String {
        if advice.rating == .great { return "Now is a great time" }
        if let best = advice.bestTimeLabel { return "Around \(best)" }
        return "No good window soon"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(Color.accentColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Best walk time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.brand(.headline))
                if advice.rating == .pawsHot, let pavement = advice.pavementNow {
                    Text("Pavement about \(Int(pavement.rounded()))°. Too hot for paws.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 8)
            RatingChip(rating: advice.rating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct RatingChip: View {
    let rating: WalkRating

    private var style: (label: String, background: UInt32, text: UInt32) {
        switch rating {
        case .great: ("Great", 0xC0DD97, 0x27500A)
        case .okay: ("Okay", 0xFAC775, 0x633806)
        case .poor: ("Stay in", 0xD3D1C7, 0x444441)
        case .pawsHot: ("Paws hot", 0xF7C1C1, 0x791F1F)
        case .tooCold: ("Too cold", 0xB5D4F4, 0x0C447C)
        }
    }

    var body: some View {
        Text(style.label)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color(hex: style.text))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(hex: style.background), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        WalkCard(advice: WalkAdvice(rating: .great, bestTimeLabel: nil))
        WalkCard(advice: WalkAdvice(rating: .okay, bestTimeLabel: "6 PM"))
        WalkCard(advice: WalkAdvice(rating: .pawsHot, bestTimeLabel: "7 PM", pavementNow: 58))
        WalkCard(advice: WalkAdvice(rating: .poor, bestTimeLabel: nil))
    }
    .padding()
}
