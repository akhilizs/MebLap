import SwiftUI
import CoreLocation

struct EmergencyView: View {
    let location: CLLocation?

    @Environment(\.dismiss) private var dismiss
    @State private var address: String?

    private var shareText: String? {
        guard let c = location?.coordinate else { return nil }
        var text = "🚨 I need help. My location:\n" + MapLinks.shareText(for: c, name: "My location")
        if let address { text += "\n\(address)" }
        return text
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Call") {
                    ForEach(LebanonData.emergencyContacts) { contact in
                        if let url = URL(string: "tel:\(contact.number)") {
                            Link(destination: url) {
                                HStack(spacing: 14) {
                                    Image(systemName: contact.symbol)
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.lebanonRed.gradient, in: RoundedRectangle(cornerRadius: 9))
                                    VStack(alignment: .leading) {
                                        Text(contact.name).foregroundStyle(.primary)
                                        Text(contact.nameAr).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(contact.number).font(.title3.bold().monospacedDigit()).foregroundStyle(Color.lebanonRed)
                                }
                            }
                        }
                    }
                }

                Section {
                    if let location {
                        VStack(alignment: .leading, spacing: 4) {
                            if let landmark = LebanonData.landmarkDescription(for: location.coordinate) {
                                Text(landmark).font(.headline)
                            }
                            if let address { Text(address).font(.subheadline) }
                            Text(String(format: "%.5f, %.5f  (±%.0f m)", location.coordinate.latitude,
                                        location.coordinate.longitude, location.horizontalAccuracy))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let shareText {
                            ShareLink(item: shareText) {
                                Label("Share my location", systemImage: "square.and.arrow.up")
                            }
                            if let wa = MapLinks.whatsApp(text: shareText) {
                                Link(destination: wa) {
                                    Label("Send on WhatsApp", systemImage: "message.fill")
                                }
                            }
                        }
                    } else {
                        Label("Location unavailable — enable Location Services", systemImage: "location.slash")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Where am I")
                } footer: {
                    Text("Describes your spot relative to the nearest known landmark, the way people give directions in Lebanon.")
                }

                Section("After an accident") {
                    Label("Turn on hazard lights and stay safe off the road", systemImage: "exclamationmark.triangle")
                    Label("Call 140 for injuries, 112 for police", systemImage: "phone")
                    Label("Photograph vehicles and plates before moving cars", systemImage: "camera")
                    Label("Wait for the insurance expert if you can", systemImage: "doc.text")
                }
            }
            .navigationTitle("Emergency · طوارئ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task(id: location?.coordinate.latitude) {
                guard let location else { return }
                let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
                address = [placemark?.thoroughfare, placemark?.subLocality, placemark?.locality]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                    .nilIfEmpty
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
