import SwiftUI
import MapKit
import Observation

enum MapTag: Hashable {
    case hazard(UUID)
    case place(String)
    case result(String)
    case pass(String)
    case destination
}

@Observable
final class MapViewModel {
    var position: MapCameraPosition = .region(LebanonGeo.region)
    var selection: MapTag?
    var mapCenter = LebanonGeo.center

    var destination: MapPlace?
    var searchResults: [MapPlace] = []
    var routeOptions: [RouteOption] = []
    var selectedRouteID: UUID?
    var isCalculating = false
    var routeError: String?
    var navigation: NavigationSession?

    var selectedRoute: RouteOption? {
        routeOptions.first { $0.id == selectedRouteID } ?? routeOptions.first
    }

    func show(_ place: MapPlace, zoom: CLLocationDistance = 2500) {
        destination = place
        routeOptions = []
        routeError = nil
        withAnimation {
            position = .region(MKCoordinateRegion(center: place.coordinate,
                                                  latitudinalMeters: zoom, longitudinalMeters: zoom))
        }
    }

    func showResults(_ places: [MapPlace]) {
        searchResults = places
        destination = nil
        routeOptions = []
        guard !places.isEmpty else { return }
        let rect = places.reduce(MKMapRect.null) { rect, place in
            rect.union(MKMapRect(origin: MKMapPoint(place.coordinate), size: MKMapSize(width: 1, height: 1)))
        }
        withAnimation { position = .rect(rect.padded(by: 0.25)) }
    }

    func clear() {
        destination = nil
        searchResults = []
        routeOptions = []
        selectedRouteID = nil
        routeError = nil
        selection = nil
    }

    @MainActor
    func calculateRoutes(from origin: CLLocationCoordinate2D?, hazards: HazardStore,
                         avoidHazards: Bool, avoidTolls: Bool, language: VoiceLanguage) async {
        guard let destination else { return }
        isCalculating = true
        routeError = nil
        defer { isCalculating = false }
        do {
            let options = try await RoutingService.routes(from: origin, to: destination, hazards: hazards,
                                                          avoidTolls: avoidTolls, language: language)
            routeOptions = options
            let preferred = avoidHazards
                ? options.min { $0.adjustedTime < $1.adjustedTime }
                : options.min { $0.route.expectedTravelTime < $1.route.expectedTravelTime }
            selectedRouteID = preferred?.id
            let rects = options.map { $0.route.polyline.boundingMapRect }
            if let first = rects.first {
                let rect = rects.dropFirst().reduce(first) { $0.union($1) }
                withAnimation { position = .rect(rect.padded(by: 0.2)) }
            }
        } catch {
            routeOptions = []
            routeError = error.localizedDescription
        }
    }

    func startNavigation(hazards: HazardStore, language: VoiceLanguage, voice: Bool) {
        guard let route = selectedRoute, let destination else { return }
        navigation?.end()
        navigation = NavigationSession(option: route, destination: destination,
                                       hazards: hazards.active, language: language, voiceEnabled: voice)
        withAnimation {
            position = .userLocation(followsHeading: true, fallback: .automatic)
        }
    }

    @MainActor
    func reroute(from location: CLLocation, hazards: HazardStore, avoidTolls: Bool,
                 language: VoiceLanguage) async {
        guard let destination, let old = navigation else { return }
        let muted = old.isMuted
        do {
            let options = try await RoutingService.routes(from: location.coordinate, to: destination,
                                                          hazards: hazards, avoidTolls: avoidTolls,
                                                          language: language)
            guard let best = options.min(by: { $0.adjustedTime < $1.adjustedTime }) else { return }
            old.end()
            routeOptions = options
            selectedRouteID = best.id
            navigation = NavigationSession(option: best, destination: destination, hazards: hazards.active,
                                           language: language, voiceEnabled: !muted)
        } catch {
            // Keep guiding on the old route and try again on the next off-route update.
            old.clearRerouteFlag()
        }
    }

    func endNavigation() {
        navigation?.end()
        navigation = nil
        if let rect = selectedRoute?.route.polyline.boundingMapRect {
            withAnimation { position = .rect(rect.padded(by: 0.2)) }
        }
    }
}
