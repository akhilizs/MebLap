import SwiftUI
import CoreLocation

enum HazardType: String, Codable, CaseIterable, Identifiable {
    case pothole
    case flooding
    case accident
    case closure
    case checkpoint
    case traffic
    case lightsOut
    case unlitRoad
    case construction
    case snowIce
    case landslide
    case roadblock
    case fuelQueue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pothole: "Pothole"
        case .flooding: "Flooded road"
        case .accident: "Accident"
        case .closure: "Road closed"
        case .checkpoint: "Checkpoint"
        case .traffic: "Heavy traffic"
        case .lightsOut: "Traffic lights out"
        case .unlitRoad: "No street lights"
        case .construction: "Road works"
        case .snowIce: "Snow / ice"
        case .landslide: "Rockfall / landslide"
        case .roadblock: "Roadblock / protest"
        case .fuelQueue: "Fuel station queue"
        }
    }

    var titleAr: String {
        switch self {
        case .pothole: "حفرة"
        case .flooding: "طريق مغمورة بالمياه"
        case .accident: "حادث سير"
        case .closure: "طريق مقطوعة"
        case .checkpoint: "حاجز"
        case .traffic: "زحمة سير"
        case .lightsOut: "إشارات السير معطلة"
        case .unlitRoad: "طريق غير مضاءة"
        case .construction: "أشغال على الطريق"
        case .snowIce: "ثلوج وجليد"
        case .landslide: "انهيار صخري"
        case .roadblock: "قطع طريق"
        case .fuelQueue: "طابور على محطة الوقود"
        }
    }

    var titleFr: String {
        switch self {
        case .pothole: "nid-de-poule"
        case .flooding: "route inondée"
        case .accident: "accident"
        case .closure: "route fermée"
        case .checkpoint: "barrage"
        case .traffic: "embouteillage"
        case .lightsOut: "feux de circulation en panne"
        case .unlitRoad: "route non éclairée"
        case .construction: "travaux"
        case .snowIce: "neige et verglas"
        case .landslide: "éboulement"
        case .roadblock: "route bloquée"
        case .fuelQueue: "file à la station"
        }
    }

    var symbol: String {
        switch self {
        case .pothole: "smallcircle.filled.circle"
        case .flooding: "water.waves"
        case .accident: "car.2.fill"
        case .closure: "xmark.octagon.fill"
        case .checkpoint: "shield.fill"
        case .traffic: "tortoise.fill"
        case .lightsOut: "lightbulb.slash.fill"
        case .unlitRoad: "moon.fill"
        case .construction: "hammer.fill"
        case .snowIce: "snowflake"
        case .landslide: "mountain.2.fill"
        case .roadblock: "flame.fill"
        case .fuelQueue: "fuelpump.fill"
        }
    }

    var color: Color {
        switch self {
        case .pothole: .brown
        case .flooding: .blue
        case .accident: .red
        case .closure: .red
        case .checkpoint: .indigo
        case .traffic: .orange
        case .lightsOut: .yellow
        case .unlitRoad: .purple
        case .construction: .orange
        case .snowIce: .cyan
        case .landslide: .brown
        case .roadblock: .red
        case .fuelQueue: .green
        }
    }

    /// How long a report stays on the map without being re-confirmed.
    var lifetime: TimeInterval {
        let hour: TimeInterval = 3600
        switch self {
        case .pothole: return 30 * 24 * hour
        case .unlitRoad: return 14 * 24 * hour
        case .construction: return 7 * 24 * hour
        case .flooding: return 6 * hour
        case .snowIce: return 12 * hour
        case .landslide: return 24 * hour
        case .closure: return 12 * hour
        case .lightsOut: return 8 * hour
        case .roadblock: return 4 * hour
        case .accident: return 2 * hour
        case .checkpoint: return 3 * hour
        case .traffic: return 1 * hour
        case .fuelQueue: return 3 * hour
        }
    }

    /// Extra seconds added to a route's cost for each hazard on it, so the
    /// "Safest" route choice steers around the worst problems.
    var routePenalty: TimeInterval {
        switch self {
        case .closure: 3 * 3600
        case .roadblock: 2 * 3600
        case .flooding: 1800
        case .landslide: 1800
        case .snowIce: 1200
        case .accident: 600
        case .traffic: 420
        case .construction: 300
        case .lightsOut: 120
        case .pothole: 90
        case .unlitRoad: 60
        case .checkpoint: 60
        case .fuelQueue: 0
        }
    }

    /// Hazards that block the road entirely.
    var isBlocking: Bool { self == .closure || self == .roadblock }

    func spokenName(language: VoiceLanguage) -> String {
        switch language {
        case .english: title.lowercased()
        case .arabic: titleAr
        case .french: titleFr
        }
    }
}

struct HazardReport: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: HazardType
    var latitude: Double
    var longitude: Double
    var createdAt = Date()
    var lastConfirmedAt = Date()
    var confirmations = 0
    var note = ""

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var expiresAt: Date { lastConfirmedAt.addingTimeInterval(type.lifetime) }
    var isActive: Bool { expiresAt > Date() }
}
