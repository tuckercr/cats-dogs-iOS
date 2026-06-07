import SwiftUI

struct ForecastView: View {
    @Bindable var geoViewModel: GeoLocationViewModel
    @Bindable var weatherViewModel: WeatherForecastViewModel

    var body: some View {
        Group {
            switch weatherViewModel.forecast {
            case .idle, .loading:
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }

            case .success(let days):
                List(days) { day in
                    ForecastDayCard(day: day)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)

            case .error(let message, let canRetry):
                VStack(alignment: .leading, spacing: 12) {
                    Text(message)
                        .foregroundStyle(.red)
                    if canRetry {
                        Button("Retry", action: loadForecast)
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .navigationTitle("Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadForecast()
        }
    }

    private func loadForecast() {
        weatherViewModel.refreshForecast(
            resolvedCityName: weatherViewModel.resolvedCity ?? "",
            latitude: geoViewModel.pinnedLatitude,
            longitude: geoViewModel.pinnedLongitude
        )
    }
}

private struct ForecastDayCard: View {
    let day: DayForecast

    var body: some View {
        HStack(spacing: 12) {
            WeatherIconView(iconCode: day.iconCode, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(day.dateLabel)
                    .font(.headline)
                Text(day.description)
                    .foregroundStyle(.secondary)
                Text(formatTempFeels(day))
            }
            Spacer()
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTempFeels(_ day: DayForecast) -> String {
        switch day.units {
        case .metric:
            String(format: "%.1f °C (feels like %.1f °C)", day.temperature, day.feelsLike)
        case .imperial:
            String(format: "%.1f °F (feels like %.1f °F)", day.temperature, day.feelsLike)
        }
    }
}
