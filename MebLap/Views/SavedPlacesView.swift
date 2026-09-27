import SwiftUI
import CoreLocation

struct SavedPlacesView: View {
    let userLocation: CLLocationCoordinate2D?
    let currentPlace: MapPlace?
    let onSelect: (MapPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SavedPlacesStore.self) private var saved

    private var hereAsPlace: MapPlace? {
        currentPlace ?? userLocation.map {
            MapPlace(id: String(format: "here-%.5f,%.5f", $0.latitude, $0.longitude),
                     name: "Current location",
                     subtitle: LebanonData.landmarkDescription(for: $0) ?? "",
                     coordinate: $0)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Home & Work") {
                    slot(title: "Home", symbol: "house.fill", place: saved.home,
                         set: { saved.setHome($0) })
                    slot(title: "Work", symbol: "briefcase.fill", place: saved.work,
                         set: { saved.setWork($0) })
                }

                Section("Favorites") {
                    if saved.favorites.isEmpty {
                        Text("Tap ☆ on any place to save it here.").foregroundStyle(.secondary)
                    }
                    ForEach(saved.favorites) { place in
                        Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { saved.removeFavorites(at: $0) }
                }

                if !saved.recents.isEmpty {
                    Section("Recent") {
                        ForEach(saved.recents) { place in
                            Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }

    @ViewBuilder
    private func slot(title: String, symbol: String, place: MapPlace?, set: @escaping (MapPlace?) -> Void) -> some View {
        if let place {
            Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Remove", role: .destructive) { set(nil) }
                }
        } else if let here = hereAsPlace {
            Button {
                set(here)
            } label: {
                Label("Set \(title) to \(here.name == "Current location" ? "current location" : here.name)",
                      systemImage: symbol)
            }
        } else {
            Label("Search for a place, then use ⋯ › Set as \(title)", systemImage: symbol)
                .foregroundStyle(.secondary)
        }
    }

    private func choose(_ place: MapPlace) {
        onSelect(place)
        dismiss()
    }
}
