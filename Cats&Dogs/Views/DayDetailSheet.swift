import SwiftUI

struct DayDetailSheet: View {
    let day: DayForecast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Divider()
                    if day.hourlySlots.isEmpty {
                        Text("Hourly data not available for this day.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        columnHeader
                        Divider()
                        ForEach(day.hourlySlots) { slot in
                            HourlySlotRow(slot: slot)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle(day.dateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            WeatherIconView(iconCode: day.iconCode, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(day.description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(WeatherFormatting.temperature(day.tempMax, units: day.units))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(WeatherFormatting.temperature(day.tempMin, units: day.units))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var columnHeader: some View {
        HStack {
            Text("TIME")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("TEMP")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("WIND")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("HUM")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HourlySlotRow: View {
    let slot: HourlySlot

    var body: some View {
        HStack(spacing: 8) {
            Text(slot.timeLabel)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            WeatherIconView(iconCode: slot.iconCode, size: 28)
            Text(WeatherFormatting.temperature(slot.temperature, units: slot.units))
                .fontWeight(.semibold)
            HStack(spacing: 2) {
                Image(systemName: "wind")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(WeatherFormatting.wind(slot.windSpeed, units: slot.units))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text("\(slot.humidity)%")
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
}
