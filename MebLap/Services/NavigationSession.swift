import MapKit
import Observation

struct HazardAhead: Equatable {
    let report: HazardReport
    let distance: CLLocationDistance
}

/// Live turn-by-turn state for one route: tracks progress along the polyline,
/// announces manoeuvres and reported hazards, and flags when a reroute is needed.
@Observable
final class NavigationSession {
    let option: RouteOption
    let destination: MapPlace
    let steps: [RouteStep]

    private(set) var stepIndex = 0
    private(set) var distanceToManeuver: CLLocationDistance = 0
    private(set) var remainingDistance: CLLocationDistance
    private(set) var remainingTime: TimeInterval
    private(set) var speedKmh: Double = 0
    private(set) var hazardAhead: HazardAhead? = nil
    private(set) var arrived = false
    private(set) var needsReroute = false

    private(set) var isMuted = false

    @ObservationIgnored private let speech: SpeechGuide
    @ObservationIgnored private let coords: [CLLocationCoordinate2D]
    @ObservationIgnored private let cumulative: [Double]
    @ObservationIgnored private let stepStarts: [Double]
    @ObservationIgnored private var hazardPositions: [(report: HazardReport, along: Double)] = []
    @ObservationIgnored private var announced: Set<String> = []
    @ObservationIgnored private var segmentIndex = 0
    @ObservationIgnored private var offRouteCount = 0

    private var totalLength: Double { cumulative.last ?? option.route.distance }
    private var averageSpeed: Double {
        option.route.expectedTravelTime > 0 ? option.route.distance / option.route.expectedTravelTime : 13
    }

    init(option: RouteOption, destination: MapPlace, hazards: [HazardReport],
         language: VoiceLanguage, voiceEnabled: Bool) {
        let coords = option.coordinates
        let cumulative = GeoMath.cumulativeDistances(coords)

        // Step start positions along the polyline, scaled so step distances
        // (from MapKit) line up with the measured polyline length.
        let polylineLength = cumulative.last ?? option.route.distance
        let scale = option.route.distance > 0 ? polylineLength / option.route.distance : 1
        var starts: [Double] = []
        var running = 0.0
        for step in option.route.steps {
            starts.append(running * scale)
            running += step.distance
        }

        let guide = SpeechGuide()
        guide.language = language
        guide.isEnabled = voiceEnabled

        self.option = option
        self.destination = destination
        self.steps = option.route.steps
        self.coords = coords
        self.cumulative = cumulative
        self.stepStarts = starts
        self.speech = guide
        self.remainingDistance = option.route.distance
        self.remainingTime = option.route.expectedTravelTime
        self.isMuted = !voiceEnabled

        updateHazards(hazards)
        distanceToManeuver = nextManeuverStart
        speech.speak(speech.starting(destination.name))
        if let first = upcomingStep, !first.instructions.isEmpty {
            speech.speak(speech.inDistance(distanceToManeuver, first.instructions))
        }
    }

    func toggleMute() {
        isMuted.toggle()
        speech.isEnabled = !isMuted
        if isMuted { speech.stop() }
    }

    /// The step whose manoeuvre the driver is heading towards.
    var upcomingStep: RouteStep? {
        let i = stepIndex + 1
        return i < steps.count ? steps[i] : nil
    }

    var currentInstruction: String {
        if arrived { return "You have arrived" }
        if let s = upcomingStep, !s.instructions.isEmpty { return s.instructions }
        return "Continue to \(destination.name)"
    }

    var maneuverSymbol: String {
        if arrived || upcomingStep == nil { return "flag.checkered" }
        return upcomingStep?.symbol ?? Self.symbol(for: upcomingStep?.instructions ?? "")
    }

    private var nextManeuverStart: Double {
        stepIndex + 1 < stepStarts.count ? stepStarts[stepIndex + 1] : totalLength
    }

    func updateHazards(_ hazards: [HazardReport]) {
        hazardPositions = hazards.compactMap { h in
            let nearest = GeoMath.nearestSegment(on: coords, to: h.coordinate)
            guard nearest.distance <= 40, nearest.index < cumulative.count else { return nil }
            let along = cumulative[nearest.index] + GeoMath.distance(coords[nearest.index], h.coordinate)
            return (report: h, along: along)
        }
    }

    func update(with location: CLLocation) {
        guard !arrived, coords.count > 1 else { return }
        speedKmh = max(0, location.speed) * 3.6

        // Where are we along the route? Search near the last position first so
        // roads that double back on themselves don't confuse us.
        let window = max(0, segmentIndex - 5)..<(segmentIndex + 250)
        var nearest = GeoMath.nearestSegment(on: coords, to: location.coordinate, in: window)
        if nearest.distance > 60 {
            nearest = GeoMath.nearestSegment(on: coords, to: location.coordinate)
        }
        segmentIndex = nearest.index

        let tolerance = max(60, location.horizontalAccuracy * 1.5)
        if nearest.distance > tolerance {
            offRouteCount += 1
            if offRouteCount >= 3 && !needsReroute {
                needsReroute = true
                speech.speak(speech.rerouting)
            }
            return
        }
        offRouteCount = 0

        let traveled = min(totalLength,
                           cumulative[segmentIndex] + GeoMath.distance(coords[segmentIndex], location.coordinate))
        remainingDistance = max(0, totalLength - traveled)
        remainingTime = remainingDistance / averageSpeed

        while stepIndex + 1 < stepStarts.count && traveled >= stepStarts[stepIndex + 1] - 10 {
            stepIndex += 1
        }
        distanceToManeuver = max(0, nextManeuverStart - traveled)

        announceManeuver()
        announceHazards(traveled: traveled)

        if remainingDistance < 30 {
            arrived = true
            speech.speak(speech.arrived(destination.name))
        }
    }

    func clearRerouteFlag() {
        needsReroute = false
        offRouteCount = 0
    }

    func end() {
        speech.stop()
    }

    private func announceManeuver() {
        guard let step = upcomingStep, !step.instructions.isEmpty else { return }
        let key = "step-\(stepIndex + 1)"
        let d = distanceToManeuver
        let highway = speedKmh > 70
        if d <= (highway ? 2000 : 1000), d > (highway ? 1200 : 500), step.distance > 1500 || highway,
           announced.insert("\(key)-far").inserted {
            speech.speak(speech.inDistance(d, step.instructions))
        } else if d <= (highway ? 500 : 250), d > 60, announced.insert("\(key)-near").inserted {
            speech.speak(speech.inDistance(d, step.instructions))
        } else if d <= 60, announced.insert("\(key)-now").inserted {
            speech.speak(step.instructions)
        }
    }

    private func announceHazards(traveled: Double) {
        let ahead = hazardPositions
            .map { (report: $0.report, distance: $0.along - traveled) }
            .filter { $0.distance > 0 && $0.distance < 1000 }
            .min { $0.distance < $1.distance }

        hazardAhead = ahead.map { HazardAhead(report: $0.report, distance: $0.distance) }
        if let ahead, ahead.distance < 600, announced.insert("hazard-\(ahead.report.id)").inserted {
            speech.speak(speech.hazardAhead(ahead.report.type, ahead.distance))
        }
    }

    /// MapKit doesn't expose manoeuvre types, so infer an arrow from the text.
    static func symbol(for instruction: String) -> String {
        let t = instruction.lowercased()
        if t.contains("u-turn") || t.contains("make a u") { return "arrow.uturn.left" }
        if t.contains("roundabout") || t.contains("rotary") || t.contains("دوار") { return "arrow.triangle.turn.up.right.circle" }
        if t.contains("exit") { return "arrow.up.right" }
        if t.contains("slight left") || t.contains("keep left") || t.contains("bear left") { return "arrow.up.left" }
        if t.contains("slight right") || t.contains("keep right") || t.contains("bear right") { return "arrow.up.right" }
        if t.contains("left") || t.contains("يسار") || t.contains("gauche") { return "arrow.turn.up.left" }
        if t.contains("right") || t.contains("يمين") || t.contains("droite") { return "arrow.turn.up.right" }
        if t.contains("arrive") || t.contains("destination") { return "flag.checkered" }
        return "arrow.up"
    }
}
