import SwiftUI

struct WeatherIconView: View {
    let iconCode: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: "https://openweathermap.org/img/wn/\(iconCode)@2x.png")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "cloud")
                    .foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(width: size, height: size)
    }
}
