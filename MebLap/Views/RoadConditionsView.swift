import SwiftUI

struct RoadConditionsView: View {
    let service: RoadConditionsService
    @Binding var showOnMap: Bool
    let onShow: (MountainPass) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(HazardStore.self) private var hazards

    private var sortedPasses: [MountainPass] {
        LebanonData.mountainPasses.sorted {
            let a = service.weather[$0.id]?.assessment.risk ?? .clear
            let b = service.weather[$1.id]?.assessment.risk ?? .clear
            return a == b ? $0.elevation > $1.elevation : a > b
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Show passes on map", isOn: $showOnMap)
                } footer: {
                    if let updated = service.lastUpdated {
                        Text("Live weather updated \(Format.relative(updated)).")
                    }
                }

                if let error = service.errorMessage {
                    Label(error, systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
                }

                Section("Mountain roads") {
                    ForEach(sortedPasses) { pass in
                        Button {
                            onShow(pass)
                            dismiss()
                        } label: {
                            PassRow(pass: pass, weather: service.weather[pass.id],
                                    reports: hazards.hazards(near: pass.coordinate, within: 5000))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Text("Weather-based risk is a guide, not an official closure notice. Always follow Internal Security Forces and Traffic Management Center announcements, and carry chains above 1,200 m in winter.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if service.isLoading && service.weather.isEmpty { ProgressView("Checking the mountains…") }
            }
            .refreshable { await service.refresh() }
            .navigationTitle("Road conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await service.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(service.isLoading)
                }
            }
            .task { await service.refreshIfStale() }
        }
    }
}

struct PassRow: View {
    let pass: MountainPass
    let weather: PassWeather?
    var reports: [HazardReport] = []

    var body: some View {
        let assessment = weather?.assessment
        HStack(alignment: .top, spacing: 12) {
            PassPin(risk: assessment?.risk)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(pass.name).font(.headline)
                    Text(pass.nameAr).font(.caption).foregroundStyle(.secondary)
                }
                Text("\(pass.road) · \(pass.elevation) m").font(.caption).foregroundStyle(.secondary)
                if let weather, let assessment {
                    HStack(spacing: 8) {
                        Label(assessment.risk.title, systemImage: assessment.risk.symbol)
                            .foregroundStyle(assessment.risk.color)
                            .font(.caption.bold())
                        Text("\(Int(weather.temperature.rounded()))°C · \(weather.conditions)")
                            .font(.caption)
                    }
                    ForEach(assessment.reasons, id: \.self) { reason in
                        Text("• \(reason)").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Weather unavailable").font(.caption).foregroundStyle(.secondary)
                }
                if !reports.isEmpty {
                    Label("\(reports.count) driver report\(reports.count == 1 ? "" : "s") nearby: " +
                          Set(reports.map(\.type.title)).sorted().joined(separator: ", "),
                          systemImage: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct PassDetailView: View {
    let pass: MountainPass
    let weather: PassWeather?
    let onNavigate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(HazardStore.self) private var hazards

    var body: some View {
        NavigationStack {
            List {
                PassRow(pass: pass, weather: weather,
                        reports: hazards.hazards(near: pass.coordinate, within: 5000))
                if let weather {
                    Section("Now") {
                        LabeledContent("Temperature", value: "\(Int(weather.temperature.rounded()))°C")
                        LabeledContent("Snowfall", value: String(format: "%.1f cm", weather.snowfall))
                        LabeledContent("Rain", value: String(format: "%.1f mm", weather.rain))
                        LabeledContent("Wind", value: "\(Int(weather.windSpeed)) km/h")
                        if let v = weather.visibility {
                            LabeledContent("Visibility", value: Format.distance(v))
                        }
                    }
                }
                Button {
                    dismiss()
                    onNavigate()
                } label: {
                    Label("Directions to \(pass.name)", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
            }
            .navigationTitle(pass.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
