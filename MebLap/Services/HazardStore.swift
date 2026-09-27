import Foundation
import CoreLocation
import Observation

/// Road hazards reported by the driver. Stored on-device; the store is the
/// single place to plug a shared backend in later so reports reach everyone.
@Observable
final class HazardStore {
    private(set) var reports: [HazardReport] = []

    @ObservationIgnored private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("hazards.json")
    }()

    init() {
        load()
        purgeExpired()
    }

    var active: [HazardReport] { reports.filter(\.isActive) }

    func report(_ type: HazardType, at coordinate: CLLocationCoordinate2D, note: String = "") {
        // Merge with an existing report of the same kind close by instead of stacking duplicates.
        if let i = reports.firstIndex(where: {
            $0.type == type && $0.isActive && GeoMath.distance($0.coordinate, coordinate) < 75
        }) {
            confirm(reports[i].id)
            return
        }
        reports.append(HazardReport(type: type, latitude: coordinate.latitude,
                                    longitude: coordinate.longitude, note: note))
        save()
    }

    func confirm(_ id: UUID) {
        guard let i = reports.firstIndex(where: { $0.id == id }) else { return }
        reports[i].confirmations += 1
        reports[i].lastConfirmedAt = Date()
        save()
    }

    func remove(_ id: UUID) {
        reports.removeAll { $0.id == id }
        save()
    }

    func report(with id: UUID) -> HazardReport? {
        reports.first { $0.id == id }
    }

    func purgeExpired() {
        let before = reports.count
        reports.removeAll { !$0.isActive }
        if reports.count != before { save() }
    }

    func hazards(near coordinate: CLLocationCoordinate2D, within meters: Double) -> [HazardReport] {
        active.filter { GeoMath.distance($0.coordinate, coordinate) <= meters }
    }

    /// Hazards lying on (within `tolerance` metres of) a route polyline.
    func hazards(onRoute coords: [CLLocationCoordinate2D], tolerance: Double = 40) -> [HazardReport] {
        guard !coords.isEmpty else { return [] }
        return active.filter { hazard in
            GeoMath.nearestSegment(on: coords, to: hazard.coordinate).distance <= tolerance
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HazardReport].self, from: data) else { return }
        reports = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
