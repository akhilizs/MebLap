import MapKit

struct RouteOption: Identifiable {
    let id = UUID()
    let route: DrivingRoute
    let coordinates: [CLLocationCoordinate2D]
    let hazards: [HazardReport]
    var label = ""

    var hazardPenalty: TimeInterval { hazards.reduce(0) { $0 + $1.type.routePenalty } }
    var adjustedTime: TimeInterval { route.expectedTravelTime + hazardPenalty }
    var isBlocked: Bool { hazards.contains { $0.type.isBlocking } }
    var hasTolls: Bool { route.hasTolls }
}

enum RoutingError: LocalizedError {
    case noRoute
    case noLocation

    var errorDescription: String? {
        switch self {
        case .noRoute: "No driving route found."
        case .noLocation: "Your location isn't available yet."
        }
    }
}

enum RoutingService {
    /// Asks Apple Maps for alternatives, falling back to OpenStreetMap routing
    /// where Apple has no coverage, then scores each route against the hazards
    /// drivers have reported so the safest option can be picked.
    static func routes(from origin: CLLocationCoordinate2D?,
                       to destination: MapPlace,
                       hazards: HazardStore,
                       avoidTolls: Bool,
                       language: VoiceLanguage) async throws -> [RouteOption] {
        let routes: [DrivingRoute]
        if let apple = try? await appleRoutes(from: origin, to: destination, avoidTolls: avoidTolls), !apple.isEmpty {
            routes = apple
        } else {
            guard let origin else { throw RoutingError.noLocation }
            routes = try await OSRMRouter.routes(from: origin, to: destination.coordinate, language: language)
        }

        let options = routes.map { route -> RouteOption in
            let coords = route.polyline.coordinates
            return RouteOption(route: route, coordinates: coords, hazards: hazards.hazards(onRoute: coords))
        }
        return label(options)
    }

    private static func appleRoutes(from origin: CLLocationCoordinate2D?, to destination: MapPlace,
                                    avoidTolls: Bool) async throws -> [DrivingRoute] {
        let request = MKDirections.Request()
        request.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
        request.destination = destination.mapItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        request.tollPreference = avoidTolls ? .avoid : .any
        let response = try await MKDirections(request: request).calculate()
        return response.routes.map { DrivingRoute($0) }
    }

    private static func label(_ options: [RouteOption]) -> [RouteOption] {
        guard let fastest = options.min(by: { $0.route.expectedTravelTime < $1.route.expectedTravelTime }) else {
            return options
        }
        let safest = options.min(by: { $0.adjustedTime < $1.adjustedTime })
        if options.count == 1 {
            var only = options[0]
            only.label = "Best route"
            return [only]
        }
        return options.map { option in
            var o = option
            if o.id == fastest.id && o.id == safest?.id {
                o.label = o.hazards.isEmpty ? "Best route" : "Fastest"
            } else if o.id == safest?.id {
                o.label = "Safest"
            } else if o.id == fastest.id {
                o.label = "Fastest"
            } else if o.route.distance == options.map(\.route.distance).min() {
                o.label = "Shortest"
            } else {
                o.label = "Alternative"
            }
            return o
        }
        .sorted { $0.adjustedTime < $1.adjustedTime }
    }
}
