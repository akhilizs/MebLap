import MapKit

/// Driving directions from OpenStreetMap data via an OSRM server. Used when
/// Apple Maps has no route (common in Lebanon). Instructions are generated
/// locally so they can be in English, Arabic or French.
enum OSRMRouter {
    /// Public demo server — fine for testing; point this at a self-hosted
    /// OSRM instance before shipping to many users.
    static var baseURL = URL(string: "https://router.project-osrm.org")!

    private struct Response: Decodable {
        let code: String
        let message: String?
        let routes: [Route]?

        struct Route: Decodable {
            let distance: Double
            let duration: Double
            let geometry: Geometry
            let legs: [Leg]
        }
        struct Geometry: Decodable {
            let coordinates: [[Double]]
        }
        struct Leg: Decodable {
            let summary: String?
            let steps: [Step]
        }
        struct Step: Decodable {
            let distance: Double
            let name: String?
            let ref: String?
            let maneuver: Maneuver
        }
        struct Maneuver: Decodable {
            let type: String
            let modifier: String?
            let exit: Int?
        }
    }

    static func routes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D,
                       language: VoiceLanguage) async throws -> [DrivingRoute] {
        let coords = String(format: "%.6f,%.6f;%.6f,%.6f",
                            origin.longitude, origin.latitude, destination.longitude, destination.latitude)
        var components = URLComponents(url: baseURL.appendingPathComponent("route/v1/driving/\(coords)"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "steps", value: "true"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "geometries", value: "geojson"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("MebLap/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.code == "Ok", let routes = response.routes, !routes.isEmpty else {
            throw RoutingError.noRoute
        }

        return routes.map { route in
            var points = route.geometry.coordinates.compactMap { pair -> CLLocationCoordinate2D? in
                pair.count >= 2 ? CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0]) : nil
            }
            let polyline = MKPolyline(coordinates: &points, count: points.count)
            let steps = route.legs.flatMap(\.steps).map { step in
                RouteStep(
                    instructions: RouteInstructions.text(type: step.maneuver.type,
                                                         modifier: step.maneuver.modifier,
                                                         exit: step.maneuver.exit,
                                                         road: roadLabel(step.name, step.ref),
                                                         language: language),
                    distance: step.distance,
                    symbol: RouteInstructions.symbol(type: step.maneuver.type, modifier: step.maneuver.modifier)
                )
            }
            let summary = route.legs.compactMap(\.summary).filter { !$0.isEmpty }.joined(separator: ", ")
            return DrivingRoute(polyline: polyline, distance: route.distance,
                                expectedTravelTime: route.duration, name: summary,
                                hasTolls: false, steps: steps, source: .openStreetMap)
        }
    }

    private static func roadLabel(_ name: String?, _ ref: String?) -> String {
        let name = name?.trimmingCharacters(in: .whitespaces) ?? ""
        let ref = ref?.trimmingCharacters(in: .whitespaces) ?? ""
        switch (name.isEmpty, ref.isEmpty) {
        case (false, false): return "\(name) (\(ref))"
        case (false, true): return name
        case (true, false): return ref
        case (true, true): return ""
        }
    }
}

enum RouteInstructions {
    static func symbol(type: String, modifier: String?) -> String {
        switch type {
        case "arrive": return "flag.checkered"
        case "roundabout", "rotary", "roundabout turn": return "arrow.triangle.turn.up.right.circle"
        case "off ramp": return modifier?.contains("left") == true ? "arrow.up.left" : "arrow.up.right"
        default: break
        }
        switch modifier ?? "" {
        case "uturn": return "arrow.uturn.left"
        case "sharp left", "left": return "arrow.turn.up.left"
        case "sharp right", "right": return "arrow.turn.up.right"
        case "slight left": return "arrow.up.left"
        case "slight right": return "arrow.up.right"
        default: return "arrow.up"
        }
    }

    static func text(type: String, modifier: String?, exit: Int?, road: String,
                     language: VoiceLanguage) -> String {
        switch language {
        case .english: return english(type, modifier, exit, road)
        case .arabic: return arabic(type, modifier, exit, road)
        case .french: return french(type, modifier, exit, road)
        }
    }

    private static func isLeft(_ m: String?) -> Bool { m?.contains("left") == true }

    // MARK: English

    private static func english(_ type: String, _ m: String?, _ exit: Int?, _ road: String) -> String {
        let onto = road.isEmpty ? "" : " onto \(road)"
        let toward = road.isEmpty ? "" : " toward \(road)"
        let side = isLeft(m) ? "left" : "right"
        let direction: String = switch m ?? "" {
        case "sharp left": "sharp left"
        case "sharp right": "sharp right"
        case "slight left": "slight left"
        case "slight right": "slight right"
        case "left": "left"
        case "right": "right"
        default: "straight"
        }
        switch type {
        case "depart": return road.isEmpty ? "Start driving" : "Start on \(road)"
        case "arrive": return "Arrive at your destination"
        case "roundabout", "rotary":
            if let exit { return "At the roundabout, take the \(englishOrdinal(exit)) exit\(onto)" }
            return "Enter the roundabout\(onto)"
        case "exit roundabout", "exit rotary": return "Exit the roundabout\(onto)"
        case "fork": return "Keep \(side) at the fork\(toward)"
        case "on ramp": return "Take the ramp on the \(side)\(onto)"
        case "off ramp": return "Take the exit on the \(side)\(toward)"
        case "merge": return "Merge \(side)\(onto)"
        case "continue", "new name":
            if m == "slight left" || m == "slight right" { return "Keep \(side)\(onto)" }
            return road.isEmpty ? "Continue straight" : "Continue onto \(road)"
        default:
            if m == "uturn" { return "Make a U-turn\(onto)" }
            if direction == "straight" { return road.isEmpty ? "Continue straight" : "Continue onto \(road)" }
            return "Turn \(direction)\(onto)"
        }
    }

    private static func englishOrdinal(_ n: Int) -> String {
        ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"][safe: n - 1] ?? "\(n)th"
    }

    // MARK: Arabic

    private static func arabic(_ type: String, _ m: String?, _ exit: Int?, _ road: String) -> String {
        let onto = road.isEmpty ? "" : " إلى \(road)"
        let side = isLeft(m) ? "اليسار" : "اليمين"
        let direction: String = switch m ?? "" {
        case "sharp left": "بشكل حاد إلى اليسار"
        case "sharp right": "بشكل حاد إلى اليمين"
        case "slight left": "قليلاً إلى اليسار"
        case "slight right": "قليلاً إلى اليمين"
        case "left": "يسارًا"
        case "right": "يمينًا"
        default: ""
        }
        switch type {
        case "depart": return road.isEmpty ? "انطلق" : "انطلق على \(road)"
        case "arrive": return "لقد وصلت إلى وجهتك"
        case "roundabout", "rotary":
            if let exit, let ordinal = ["الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس"][safe: exit - 1] {
                return "عند الدوار، اسلك المخرج \(ordinal)\(onto)"
            }
            return "ادخل الدوار\(onto)"
        case "exit roundabout", "exit rotary": return "اخرج من الدوار\(onto)"
        case "fork": return "ابقَ على \(side) عند التفرع\(onto)"
        case "on ramp": return "اسلك المنحدر على \(side)\(onto)"
        case "off ramp": return "اسلك المخرج على \(side)\(onto)"
        case "merge": return "اندمج\(onto)"
        case "continue", "new name":
            return road.isEmpty ? "تابع مباشرة" : "تابع على \(road)"
        default:
            if m == "uturn" { return "استدر للخلف\(onto)" }
            if direction.isEmpty { return road.isEmpty ? "تابع مباشرة" : "تابع على \(road)" }
            return "انعطف \(direction)\(onto)"
        }
    }

    // MARK: French

    private static func french(_ type: String, _ m: String?, _ exit: Int?, _ road: String) -> String {
        let onto = road.isEmpty ? "" : " sur \(road)"
        let toward = road.isEmpty ? "" : " vers \(road)"
        let side = isLeft(m) ? "à gauche" : "à droite"
        let direction: String = switch m ?? "" {
        case "sharp left": "franchement à gauche"
        case "sharp right": "franchement à droite"
        case "slight left": "légèrement à gauche"
        case "slight right": "légèrement à droite"
        case "left": "à gauche"
        case "right": "à droite"
        default: ""
        }
        switch type {
        case "depart": return road.isEmpty ? "Partez" : "Partez sur \(road)"
        case "arrive": return "Vous êtes arrivé à destination"
        case "roundabout", "rotary":
            if let exit, let ordinal = ["première", "deuxième", "troisième", "quatrième", "cinquième", "sixième"][safe: exit - 1] {
                return "Au rond-point, prenez la \(ordinal) sortie\(onto)"
            }
            return "Entrez dans le rond-point\(onto)"
        case "exit roundabout", "exit rotary": return "Sortez du rond-point\(onto)"
        case "fork": return "Restez \(side) à l'embranchement\(toward)"
        case "on ramp": return "Prenez la bretelle \(side)\(onto)"
        case "off ramp": return "Prenez la sortie \(side)\(toward)"
        case "merge": return "Rejoignez la voie\(onto)"
        case "continue", "new name":
            return road.isEmpty ? "Continuez tout droit" : "Continuez\(onto)"
        default:
            if m == "uturn" { return "Faites demi-tour\(onto)" }
            if direction.isEmpty { return road.isEmpty ? "Continuez tout droit" : "Continuez\(onto)" }
            return "Tournez \(direction)\(onto)"
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
