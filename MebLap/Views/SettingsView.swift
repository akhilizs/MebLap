import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HazardStore.self) private var hazards
    @Environment(SavedPlacesStore.self) private var saved
    @Environment(LocationManager.self) private var location

    @AppStorage(SettingsKey.mapStyle) private var mapStyle = MapStyleOption.standard.rawValue
    @AppStorage(SettingsKey.showTraffic) private var showTraffic = true
    @AppStorage(SettingsKey.showHazards) private var showHazards = true
    @AppStorage(SettingsKey.showPasses) private var showPasses = false
    @AppStorage(SettingsKey.showLandmarks) private var showLandmarks = false
    @AppStorage(SettingsKey.avoidHazards) private var avoidHazards = true
    @AppStorage(SettingsKey.avoidTolls) private var avoidTolls = false
    @AppStorage(SettingsKey.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKey.voiceLanguage) private var voiceLanguage = VoiceLanguage.english.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Map") {
                    Picker("Style", selection: $mapStyle) {
                        ForEach(MapStyleOption.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Live traffic", isOn: $showTraffic)
                    Toggle("Road hazards", isOn: $showHazards)
                    Toggle("Mountain passes", isOn: $showPasses)
                    Toggle("Lebanon landmarks", isOn: $showLandmarks)
                }

                Section {
                    Toggle("Prefer routes without hazards", isOn: $avoidHazards)
                    Toggle("Avoid tolls", isOn: $avoidTolls)
                } header: {
                    Text("Routing")
                } footer: {
                    Text("Routes are scored against reported closures, floods, roadblocks and other hazards so MebLap can pick the safest way, not just the fastest.")
                }

                Section {
                    Toggle("Voice guidance", isOn: $voiceEnabled)
                    Picker("Voice language", selection: $voiceLanguage) {
                        ForEach(VoiceLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Turn instructions follow your iPhone's language; alerts and distances are spoken in the language you pick.")
                }

                Section("Your data") {
                    LabeledContent("Active hazard reports", value: "\(hazards.active.count)")
                    LabeledContent("Saved places", value: "\(saved.favorites.count)")
                    Button("Clear recent searches", role: .destructive) { saved.clearRecents() }
                    if !location.isAuthorized {
                        Button("Enable location access") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("MebLap — maps built for Lebanon's roads. Map data © Apple. Mountain weather from Open-Meteo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
