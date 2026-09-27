import SwiftUI
import MapKit

enum SettingsKey {
    static let mapStyle = "mapStyle"
    static let showTraffic = "showTraffic"
    static let showHazards = "showHazards"
    static let showPasses = "showPasses"
    static let showLandmarks = "showLandmarks"
    static let avoidHazards = "avoidHazards"
    static let avoidTolls = "avoidTolls"
    static let voiceEnabled = "voiceEnabled"
    static let voiceLanguage = "voiceLanguage"
    static let fuelPricePer20L = "fuelPricePer20L"
    static let consumption = "consumptionPer100km"
    static let usdRate = "usdRate"
    static let taxiBaseFare = "taxiBaseFare"
    static let taxiPerKm = "taxiPerKm"
    static let serviceFare = "serviceFare"
}

/// Defaults for the money settings. These drift quickly in Lebanon, so all of
/// them are editable in Settings and the Trip Cost screen.
enum Defaults {
    static let fuelPricePer20L: Double = 1_450_000
    static let consumption: Double = 9.0
    static let usdRate: Double = 89_500
    static let taxiBaseFare: Double = 300_000
    static let taxiPerKm: Double = 60_000
    static let serviceFare: Double = 250_000
}

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard, hybrid, satellite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Map"
        case .hybrid: "Hybrid"
        case .satellite: "Satellite"
        }
    }

    func style(traffic: Bool) -> MapStyle {
        switch self {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: traffic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: traffic)
        case .satellite: .imagery(elevation: .realistic)
        }
    }
}

/// Lebanon is trilingual on the road — guidance can speak any of the three.
enum VoiceLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    case arabic = "ar-SA"
    case french = "fr-FR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .arabic: "العربية"
        case .french: "Français"
        }
    }
}
