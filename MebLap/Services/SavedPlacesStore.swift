import Foundation
import Observation

@Observable
final class SavedPlacesStore {
    private(set) var home: MapPlace?
    private(set) var work: MapPlace?
    private(set) var favorites: [MapPlace] = []
    private(set) var recents: [MapPlace] = []

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        home = decode("saved.home")
        work = decode("saved.work")
        favorites = decode("saved.favorites") ?? []
        recents = decode("saved.recents") ?? []
    }

    func setHome(_ place: MapPlace?) {
        home = place.map { renamed($0, "Home", "house.fill") }
        encode(home, "saved.home")
    }

    func setWork(_ place: MapPlace?) {
        work = place.map { renamed($0, "Work", "briefcase.fill") }
        encode(work, "saved.work")
    }

    func isFavorite(_ place: MapPlace) -> Bool {
        favorites.contains { $0.id == place.id }
    }

    func toggleFavorite(_ place: MapPlace) {
        if isFavorite(place) {
            favorites.removeAll { $0.id == place.id }
        } else {
            favorites.insert(place, at: 0)
        }
        encode(favorites, "saved.favorites")
    }

    func removeFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        encode(favorites, "saved.favorites")
    }

    func addRecent(_ place: MapPlace) {
        recents.removeAll { $0.id == place.id }
        recents.insert(place, at: 0)
        recents = Array(recents.prefix(15))
        encode(recents, "saved.recents")
    }

    func clearRecents() {
        recents = []
        encode(recents, "saved.recents")
    }

    private func renamed(_ place: MapPlace, _ name: String, _ symbol: String) -> MapPlace {
        var p = place
        if p.name != name { p.subtitle = p.name == "Dropped pin" ? p.subtitle : p.name }
        p.name = name
        p.symbol = symbol
        return p
    }

    private func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
