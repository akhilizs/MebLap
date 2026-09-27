import SwiftUI
import CoreLocation

extension Color {
    /// Cedar green and red from the Lebanese flag.
    static let cedar = Color(red: 0, green: 0.65, blue: 0.32)
    static let lebanonRed = Color(red: 0.93, green: 0.11, blue: 0.14)
}

struct HazardPin: View {
    let type: HazardType

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(type.color.gradient, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
    }
}

struct PassPin: View {
    let risk: PassRisk?

    var body: some View {
        Image(systemName: "mountain.2.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background((risk?.color ?? .gray).gradient, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
    }
}

struct CircleButton: View {
    let symbol: String
    var tint: Color = .primary
    var background: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(background == nil ? tint : .white)
                .frame(width: 46, height: 46)
                .background {
                    if let background {
                        Circle().fill(background)
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct PlaceRow: View {
    let place: MapPlace
    let from: CLLocationCoordinate2D?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.symbol)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.cedar.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.body.weight(.medium)).lineLimit(1)
                if !place.subtitle.isEmpty {
                    Text(place.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            if let from {
                Text(Format.distance(GeoMath.distance(from, place.coordinate)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct Chip: View {
    let title: String
    let symbol: String
    var tint: Color = .cedar
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}

struct PanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
    }
}

enum MapLinks {
    static func appleMaps(_ c: CLLocationCoordinate2D, name: String) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(c.latitude),\(c.longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return components.url!
    }

    static func googleMaps(_ c: CLLocationCoordinate2D) -> URL {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(c.latitude),\(c.longitude)")!
    }

    static func whatsApp(text: String) -> URL? {
        var components = URLComponents(string: "https://wa.me/")!
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url
    }

    static func shareText(for c: CLLocationCoordinate2D, name: String) -> String {
        var lines = [name]
        if let landmark = LebanonData.landmarkDescription(for: c) { lines.append(landmark) }
        lines.append(String(format: "%.5f, %.5f", c.latitude, c.longitude))
        lines.append(appleMaps(c, name: name).absoluteString)
        lines.append(googleMaps(c).absoluteString)
        return lines.joined(separator: "\n")
    }
}
