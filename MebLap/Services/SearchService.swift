import MapKit
import Observation

enum QuickCategory: String, CaseIterable, Identifiable {
    case gas, hospital, pharmacy, parking, atm, restaurant, cafe, evCharger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gas: "Fuel"
        case .hospital: "Hospitals"
        case .pharmacy: "Pharmacies"
        case .parking: "Parking"
        case .atm: "ATMs"
        case .restaurant: "Food"
        case .cafe: "Coffee"
        case .evCharger: "EV charging"
        }
    }

    var symbol: String {
        switch self {
        case .gas: "fuelpump.fill"
        case .hospital: "cross.case.fill"
        case .pharmacy: "pills.fill"
        case .parking: "parkingsign"
        case .atm: "banknote.fill"
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .evCharger: "bolt.car.fill"
        }
    }

    var query: String {
        switch self {
        case .gas: "gas station"
        case .hospital: "hospital"
        case .pharmacy: "pharmacy"
        case .parking: "parking"
        case .atm: "ATM"
        case .restaurant: "restaurant"
        case .cafe: "cafe"
        case .evCharger: "EV charger"
        }
    }

    var poiCategory: MKPointOfInterestCategory {
        switch self {
        case .gas: .gasStation
        case .hospital: .hospital
        case .pharmacy: .pharmacy
        case .parking: .parking
        case .atm: .atm
        case .restaurant: .restaurant
        case .cafe: .cafe
        case .evCharger: .evCharger
        }
    }
}

@Observable
final class SearchService {
    var results: [MapPlace] = []
    var isSearching = false

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Debounced search: built-in Lebanese gazetteer first (handles Arabic and
    /// alternative spellings like Saida/Sidon), then Apple Maps, limited to Lebanon.
    func search(_ text: String, near center: CLLocationCoordinate2D) {
        task?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }
        let local = Self.localMatches(query)
        results = local
        isSearching = true
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
            request.resultTypes = [.pointOfInterest, .address]
            let remote = await Self.run(request)
            guard !Task.isCancelled else { return }
            let localIDs = Set(local.map { $0.name.lowercased() })
            results = local + remote.filter { !localIDs.contains($0.name.lowercased()) }
            isSearching = false
        }
    }

    func search(category: QuickCategory, near center: CLLocationCoordinate2D) async -> [MapPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.query
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category.poiCategory])
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
        let found = await Self.run(request)
        return found.sorted {
            GeoMath.distance($0.coordinate, center) < GeoMath.distance($1.coordinate, center)
        }
    }

    static func localMatches(_ query: String) -> [MapPlace] {
        let q = TextNormalizer.normalize(query)
        guard !q.isEmpty else { return [] }
        let scored: [(LebanonPlace, Int)] = LebanonData.places.compactMap { place in
            let keys = place.searchKeys
            if keys.contains(q) { return (place, 0) }
            if keys.contains(where: { $0.hasPrefix(q) }) { return (place, 1) }
            if keys.contains(where: { $0.contains(q) }) { return (place, 2) }
            return nil
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(8).map { MapPlace($0.0) }
    }

    private static func run(_ request: MKLocalSearch.Request) async -> [MapPlace] {
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
                .filter { LebanonGeo.contains($0.placemark.coordinate) }
                .map { MapPlace($0) }
        } catch {
            return []
        }
    }
}
