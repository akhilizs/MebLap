import CoreLocation
import MapKit

enum GeoMath {
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Distance in metres from `p` to the segment `a`–`b`, using a local flat
    /// projection (accurate enough at road scale).
    static func distance(from p: CLLocationCoordinate2D,
                         toSegment a: CLLocationCoordinate2D,
                         _ b: CLLocationCoordinate2D) -> Double {
        let mPerLat = 111_320.0
        let mPerLon = 111_320.0 * cos(p.latitude * .pi / 180)
        let ax = (a.longitude - p.longitude) * mPerLon, ay = (a.latitude - p.latitude) * mPerLat
        let bx = (b.longitude - p.longitude) * mPerLon, by = (b.latitude - p.latitude) * mPerLat
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy
        var t = len2 > 0 ? -(ax * dx + ay * dy) / len2 : 0
        t = max(0, min(1, t))
        let cx = ax + t * dx, cy = ay + t * dy
        return (cx * cx + cy * cy).squareRoot()
    }

    /// Nearest segment of a polyline to `p`, optionally limited to a window of indices.
    static func nearestSegment(on coords: [CLLocationCoordinate2D],
                               to p: CLLocationCoordinate2D,
                               in range: Range<Int>? = nil) -> (distance: Double, index: Int) {
        guard coords.count > 1 else {
            return (coords.first.map { distance($0, p) } ?? .infinity, 0)
        }
        let full = 0..<(coords.count - 1)
        let r = range.map { $0.clamped(to: full) } ?? full
        var best = (distance: Double.infinity, index: 0)
        for i in r {
            let d = distance(from: p, toSegment: coords[i], coords[i + 1])
            if d < best.distance { best = (d, i) }
        }
        return best
    }

    /// Running distance along the polyline at each vertex.
    static func cumulativeDistances(_ coords: [CLLocationCoordinate2D]) -> [Double] {
        var result = [Double](repeating: 0, count: coords.count)
        for i in coords.indices.dropFirst() {
            result[i] = result[i - 1] + distance(coords[i - 1], coords[i])
        }
        return result
    }

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    static func compassName(_ bearing: Double) -> String {
        let names = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        return names[Int((bearing + 22.5) / 45) % 8]
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

extension MKMapRect {
    func padded(by fraction: Double) -> MKMapRect {
        insetBy(dx: -size.width * fraction, dy: -size.height * fraction)
    }
}
