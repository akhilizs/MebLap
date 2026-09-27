import MapKit

enum RouteSource {
    case apple
    case openStreetMap
}

struct RouteStep {
    let instructions: String
    let distance: CLLocationDistance
    /// Manoeuvre arrow, when the routing engine tells us the manoeuvre type.
    var symbol: String?
}

/// A driving route from either Apple Maps or OpenStreetMap (OSRM). Apple's
/// routing doesn't cover Lebanon everywhere, so both feed the same model.
struct DrivingRoute {
    let polyline: MKPolyline
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let name: String
    let hasTolls: Bool
    let steps: [RouteStep]
    let source: RouteSource

    init(polyline: MKPolyline, distance: CLLocationDistance, expectedTravelTime: TimeInterval,
         name: String, hasTolls: Bool, steps: [RouteStep], source: RouteSource) {
        self.polyline = polyline
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.name = name
        self.hasTolls = hasTolls
        self.steps = steps
        self.source = source
    }

    init(_ route: MKRoute) {
        self.init(polyline: route.polyline,
                  distance: route.distance,
                  expectedTravelTime: route.expectedTravelTime,
                  name: route.name,
                  hasTolls: route.hasTolls,
                  steps: route.steps.map { RouteStep(instructions: $0.instructions, distance: $0.distance) },
                  source: .apple)
    }
}
