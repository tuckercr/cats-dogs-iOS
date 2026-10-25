import SwiftUI

struct WeatherIconView: View {
    let iconCode: String
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AsyncImage(url: URL(string: "https://openweathermap.org/img/wn/\(iconCode)@2x.png")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "cloud")
                    .foregroundStyle(Color.secondaryText)
            default:
                ProgressView()
            }
        }
        .frame(width: size, height: size)
        // OpenWeather's night icons are a dark grey disc (about 1.5:1 on the dark theme's cards),
        // so in dark mode each icon sits on the light theme's card colour, where all of them read.
        .background {
            if colorScheme == .dark {
                Circle().fill(Color(hex: 0xB3DDF2))
            }
        }
    }
}
