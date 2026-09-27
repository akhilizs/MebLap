import SwiftUI
import MapKit

struct SearchView: View {
    let center: CLLocationCoordinate2D
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (MapPlace) -> Void
    let onResults: ([MapPlace]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SavedPlacesStore.self) private var saved
    @State private var search = SearchService()
    @State private var text = ""
    @State private var loadingCategory: QuickCategory?

    var body: some View {
        NavigationStack {
            List {
                if text.isEmpty {
                    emptyState
                } else if search.results.isEmpty {
                    if search.isSearching {
                        HStack { ProgressView(); Text("Searching…").foregroundStyle(.secondary) }
                    } else {
                        ContentUnavailableView.search(text: text)
                    }
                } else {
                    ForEach(search.results) { place in
                        Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Places, streets, landmarks · بالعربي")
            .autocorrectionDisabled()
            .onChange(of: text) { search.search(text, near: center) }
            .navigationTitle("Search Lebanon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Section("Nearby") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickCategory.allCases) { category in
                        Chip(title: category.title, symbol: category.symbol) { searchCategory(category) }
                            .overlay {
                                if loadingCategory == category { ProgressView() }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        }

        if !pinned.isEmpty {
            Section("Saved") {
                ForEach(pinned) { place in
                    Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                        .buttonStyle(.plain)
                }
            }
        }

        if !saved.recents.isEmpty {
            Section {
                ForEach(saved.recents) { place in
                    Button { choose(place) } label: { PlaceRow(place: place, from: userLocation) }
                        .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") { saved.clearRecents() }.font(.caption)
                }
            }
        }

        Section("Explore Lebanon") {
            ForEach(LebanonData.places.filter { $0.category == .city }.prefix(8)) { place in
                Button { choose(MapPlace(place)) } label: {
                    PlaceRow(place: MapPlace(place), from: userLocation)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pinned: [MapPlace] {
        var seen = Set<String>()
        return ([saved.home, saved.work].compactMap { $0 } + saved.favorites)
            .filter { seen.insert($0.id).inserted }
    }

    private func choose(_ place: MapPlace) {
        onSelect(place)
        dismiss()
    }

    private func searchCategory(_ category: QuickCategory) {
        loadingCategory = category
        Task {
            let results = await search.search(category: category, near: center)
            loadingCategory = nil
            if !results.isEmpty {
                onResults(results)
                dismiss()
            }
        }
    }
}
