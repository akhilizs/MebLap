import SwiftUI

/// Fuel and taxi cost for the selected route, in LBP and USD. Lebanese fuel
/// prices are published per 20 litres (a "tanaka") and change weekly, so the
/// inputs are editable and remembered.
struct TripCostView: View {
    let distance: Double
    let duration: TimeInterval

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.fuelPricePer20L) private var fuelPrice = Defaults.fuelPricePer20L
    @AppStorage(SettingsKey.consumption) private var consumption = Defaults.consumption
    @AppStorage(SettingsKey.usdRate) private var usdRate = Defaults.usdRate
    @AppStorage(SettingsKey.taxiBaseFare) private var taxiBase = Defaults.taxiBaseFare
    @AppStorage(SettingsKey.taxiPerKm) private var taxiPerKm = Defaults.taxiPerKm
    @AppStorage(SettingsKey.serviceFare) private var serviceFare = Defaults.serviceFare
    @State private var roundTrip = false
    @State private var passengers = 1

    private var km: Double { distance / 1000 * (roundTrip ? 2 : 1) }
    private var liters: Double { km * consumption / 100 }
    private var fuelCost: Double { liters * fuelPrice / 20 }
    private var taxiCost: Double { taxiBase + taxiPerKm * km }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    LabeledContent("Distance", value: Format.distance(km * 1000))
                    LabeledContent("Driving time", value: Format.duration(duration * (roundTrip ? 2 : 1)))
                    Toggle("Round trip", isOn: $roundTrip)
                }

                Section {
                    LabeledContent("Fuel used", value: String(format: "%.1f L", liters))
                    LabeledContent("Fuel cost") {
                        VStack(alignment: .trailing) {
                            Text(Format.lbp(fuelCost)).bold()
                            Text(Format.usd(fuelCost / max(usdRate, 1))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Stepper("Split between \(passengers)", value: $passengers, in: 1...7)
                    if passengers > 1 {
                        LabeledContent("Each pays", value: Format.lbp(fuelCost / Double(passengers)))
                    }
                } header: {
                    Text("Driving your car")
                }

                Section {
                    LabeledContent("Taxi estimate") {
                        VStack(alignment: .trailing) {
                            Text(Format.lbp(taxiCost)).bold()
                            Text(Format.usd(taxiCost / max(usdRate, 1))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Service (shared taxi), per ride", value: Format.lbp(serviceFare))
                } header: {
                    Text("Taxi / Service")
                } footer: {
                    Text("Estimates only — agree on the fare with the driver before you ride.")
                }

                Section {
                    numberField("Fuel price per 20 L (LBP)", value: $fuelPrice)
                    numberField("Consumption (L / 100 km)", value: $consumption)
                    numberField("USD rate (LBP per $)", value: $usdRate)
                    numberField("Taxi flag-fall (LBP)", value: $taxiBase)
                    numberField("Taxi per km (LBP)", value: $taxiPerKm)
                    numberField("Service fare (LBP)", value: $serviceFare)
                } header: {
                    Text("Prices")
                } footer: {
                    Text("Update fuel prices from the Ministry of Energy's weekly price list.")
                }
            }
            .navigationTitle("Trip cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }
}
