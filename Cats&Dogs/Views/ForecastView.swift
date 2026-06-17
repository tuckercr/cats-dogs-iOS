import SwiftUI

struct ForecastView: View {
    @Bindable var cityListViewModel: CityListViewModel
    @Bindable var weatherViewModel: WeatherForecastViewModel

    @State private var selectedDay: DayForecast?

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
                    Button {
                        selectedDay = day
                    } label: {
                        ForecastDayCard(day: day)
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(day: day)
        }
    }

    private func loadForecast() {
        guard let location = cityListViewModel.activeLocation else { return }
        weatherViewModel.refreshForecast(location: location)
    }
}

private struct ForecastDayCard: View {
    let day: DayForecast

    var body: some View {
        HStack(spacing: 12) {
            WeatherIconView(iconCode: day.iconCode, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(day.dateLabel)
                    .font(.headline)
                Text(day.description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(WeatherFormatting.temperature(day.tempMax, units: day.units))
                    .fontWeight(.bold)
                Text(WeatherFormatting.temperature(day.tempMin, units: day.units))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
