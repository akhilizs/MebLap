import SwiftUI
import Observation

enum PassRisk: Int, Comparable {
    case clear, caution, danger

    static func < (a: PassRisk, b: PassRisk) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .clear: "Clear"
        case .caution: "Caution"
        case .danger: "Dangerous"
        }
    }

    var color: Color {
        switch self {
        case .clear: .green
        case .caution: .orange
        case .danger: .red
        }
    }

    var symbol: String {
        switch self {
        case .clear: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .danger: "xmark.octagon.fill"
        }
    }
}

struct PassWeather {
    let temperature: Double
    let snowfall: Double
    let rain: Double
    let windSpeed: Double
    let visibility: Double?
    let weatherCode: Int

    var conditions: String { Self.describe(weatherCode) }

    /// Driving risk derived from live weather at the pass.
    var assessment: (risk: PassRisk, reasons: [String]) {
        var risk = PassRisk.clear
        var reasons: [String] = []
        let snowCodes: Set<Int> = [71, 73, 75, 77, 85, 86]
        let freezingCodes: Set<Int> = [56, 57, 66, 67]

        if snowfall > 0.2 || snowCodes.contains(weatherCode) {
            risk = .danger; reasons.append("Snowing — chains or 4x4 likely required")
        }
        if freezingCodes.contains(weatherCode) || (temperature <= 0 && rain > 0) {
            risk = .danger; reasons.append("Freezing rain / black ice")
        } else if temperature <= 2 {
            risk = max(risk, .caution); reasons.append("Near freezing — watch for ice")
        }
        if let v = visibility {
            if v < 200 { risk = .danger; reasons.append("Very thick fog (\(Int(v)) m visibility)") }
            else if v < 1000 { risk = max(risk, .caution); reasons.append("Fog (\(Int(v)) m visibility)") }
        } else if weatherCode == 45 || weatherCode == 48 {
            risk = max(risk, .caution); reasons.append("Fog")
        }
        if windSpeed > 70 { risk = .danger; reasons.append("Storm-force wind (\(Int(windSpeed)) km/h)") }
        else if windSpeed > 45 { risk = max(risk, .caution); reasons.append("Strong wind (\(Int(windSpeed)) km/h)") }
        if rain > 4 { risk = max(risk, .caution); reasons.append("Heavy rain — flooding possible") }
        if reasons.isEmpty { reasons.append("No weather hazards right now") }
        return (risk, reasons)
    }

    static func describe(_ code: Int) -> String {
        switch code {
        case 0: "Clear sky"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing drizzle"
        case 61, 63, 65: "Rain"
        case 66, 67: "Freezing rain"
        case 71, 73, 75, 77: "Snow"
        case 80, 81, 82: "Rain showers"
        case 85, 86: "Snow showers"
        case 95, 96, 99: "Thunderstorm"
        default: "—"
        }
    }
}

/// Live weather at Lebanon's mountain passes (Open-Meteo, no API key needed).
@Observable
final class RoadConditionsService {
    var weather: [String: PassWeather] = [:]
    var lastUpdated: Date?
    var isLoading = false
    var errorMessage: String?

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let rain: Double?
            let snowfall: Double?
            let weather_code: Int
            let wind_speed_10m: Double
            let visibility: Double?
        }
        let current: Current
    }

    func refreshIfStale() async {
        if let last = lastUpdated, Date().timeIntervalSince(last) < 15 * 60 { return }
        await refresh()
    }

    @MainActor
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var results: [String: PassWeather] = [:]
        await withTaskGroup(of: (String, PassWeather?).self) { group in
            for pass in LebanonData.mountainPasses {
                group.addTask { (pass.id, await Self.fetch(pass)) }
            }
            for await (id, w) in group {
                if let w { results[id] = w }
            }
        }
        if results.isEmpty {
            errorMessage = "Couldn't load weather. Check your connection."
        } else {
            weather = results
            lastUpdated = Date()
        }
    }

    private static func fetch(_ pass: MountainPass) async -> PassWeather? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(pass.latitude)),
            URLQueryItem(name: "longitude", value: String(pass.longitude)),
            URLQueryItem(name: "elevation", value: String(pass.elevation)),
            URLQueryItem(name: "current", value: "temperature_2m,rain,snowfall,weather_code,wind_speed_10m,visibility"),
            URLQueryItem(name: "timezone", value: "Asia/Beirut"),
        ]
        guard let url = components.url,
              let result = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(Response.self, from: result.0) else { return nil }
        let c = decoded.current
        return PassWeather(temperature: c.temperature_2m, snowfall: c.snowfall ?? 0, rain: c.rain ?? 0,
                           windSpeed: c.wind_speed_10m, visibility: c.visibility, weatherCode: c.weather_code)
    }
}
