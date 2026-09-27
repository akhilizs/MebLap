import SwiftUI
import MapKit

struct NavigationHUD: View {
    let session: NavigationSession
    let isRerouting: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: session.maneuverSymbol)
                    .font(.system(size: 40, weight: .bold))
                    .frame(width: 58)
                VStack(alignment: .leading, spacing: 2) {
                    if isRerouting {
                        Text("Rerouting…").font(.title2.bold())
                    } else {
                        Text(session.arrived ? "Arrived" : Format.distance(session.distanceToManeuver))
                            .font(.title.bold())
                            .monospacedDigit()
                    }
                    Text(session.currentInstruction)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .foregroundStyle(.white)
            .background(Color.cedar.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if let ahead = session.hazardAhead {
                HStack(spacing: 10) {
                    HazardPin(type: ahead.report.type)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ahead.report.type.title).font(.subheadline.bold())
                        Text("\(Format.distance(ahead.distance)) ahead · reported \(Format.relative(ahead.report.lastConfirmedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ahead.report.type.color, lineWidth: 2))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .animation(.spring, value: session.hazardAhead)
    }
}

struct NavigationBottomBar: View {
    let session: NavigationSession
    let onReport: () -> Void
    let onEnd: () -> Void

    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(Int(session.speedKmh.rounded()))")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Text("km/h").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 60, height: 60)
                .background(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.arrival(after: session.remainingTime))
                        .font(.title2.bold())
                    Text("\(Format.duration(session.remainingTime)) · \(Format.distance(session.remainingDistance))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                CircleButton(symbol: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                    session.toggleMute()
                }
                CircleButton(symbol: "exclamationmark.bubble.fill", background: .orange, action: onReport)
                CircleButton(symbol: "xmark", background: .lebanonRed, action: onEnd)
            }
        }
    }
}

struct RoutePanel: View {
    let vm: MapViewModel
    let destination: MapPlace
    @Binding var avoidHazards: Bool
    @Binding var avoidTolls: Bool
    let onStart: () -> Void
    let onTripCost: () -> Void
    let onClose: () -> Void

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Directions").font(.caption).foregroundStyle(.secondary)
                        Text(destination.name).font(.headline).lineLimit(1)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }

                if vm.isCalculating {
                    HStack {
                        ProgressView()
                        Text("Finding the best roads…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.routeOptions) { option in
                                RouteOptionCard(option: option, isSelected: option.id == vm.selectedRoute?.id)
                                    .onTapGesture { vm.selectedRouteID = option.id }
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Toggle(isOn: $avoidHazards) {
                        Label("Avoid hazards", systemImage: "exclamationmark.shield.fill")
                    }
                    .toggleStyle(.button)
                    Toggle(isOn: $avoidTolls) {
                        Label("No tolls", systemImage: "dollarsign.circle")
                    }
                    .toggleStyle(.button)
                }
                .font(.caption)
                .tint(.cedar)

                if vm.selectedRoute?.route.source == .openStreetMap {
                    Text("Route data © OpenStreetMap contributors")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: onStart) {
                        Label("Start", systemImage: "location.north.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.cedar)
                    .disabled(vm.selectedRoute == nil)

                    Button(action: onTripCost) {
                        Label("Cost", systemImage: "fuelpump.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(vm.selectedRoute == nil)
                }
            }
        }
    }
}

struct RouteOptionCard: View {
    let option: RouteOption
    let isSelected: Bool

    private var hazardTypes: [HazardType] {
        var seen = Set<HazardType>()
        return option.hazards.map(\.type).filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.label).font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((option.label == "Safest" ? Color.cedar : Color.blue).opacity(0.18), in: Capsule())
                if option.hasTolls {
                    Image(systemName: "dollarsign.circle.fill").foregroundStyle(.orange).font(.caption)
                }
            }
            Text(Format.duration(option.route.expectedTravelTime))
                .font(.title3.bold())
            Text("\(Format.distance(option.route.distance)) · arrive \(Format.arrival(after: option.route.expectedTravelTime))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if option.isBlocked {
                Label("Road reported closed", systemImage: "xmark.octagon.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.lebanonRed)
            } else if hazardTypes.isEmpty {
                Label("No reported hazards", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Color.cedar)
            } else {
                HStack(spacing: 4) {
                    ForEach(hazardTypes.prefix(5)) { type in
                        Image(systemName: type.symbol).foregroundStyle(type.color)
                    }
                    Text("\(option.hazards.count) reported").foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            if !option.route.name.isEmpty {
                Text("via \(option.route.name)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 200, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.blue : .clear, lineWidth: 2.5)
        )
    }
}

struct PlaceCard: View {
    @Environment(SavedPlacesStore.self) private var saved

    let place: MapPlace
    let userLocation: CLLocationCoordinate2D?
    let nearbyHazards: Int
    let onDirections: () -> Void
    let onClose: () -> Void

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.title3.bold())
                        if !place.subtitle.isEmpty {
                            Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            if let userLocation {
                                Label(Format.distance(GeoMath.distance(userLocation, place.coordinate)),
                                      systemImage: "location.fill")
                            }
                            if nearbyHazards > 0 {
                                Label("\(nearbyHazards) hazard\(nearbyHazards == 1 ? "" : "s") within 2 km",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onDirections) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .layoutPriority(1)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.cedar)

                    Button { saved.toggleFavorite(place) } label: {
                        Image(systemName: saved.isFavorite(place) ? "star.fill" : "star")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.yellow)

                    ShareLink(item: MapLinks.shareText(for: place.coordinate, name: place.name)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Menu {
                        Button("Set as Home", systemImage: "house") { saved.setHome(place) }
                        Button("Set as Work", systemImage: "briefcase") { saved.setWork(place) }
                        if let phone = place.phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                            Link(destination: url) { Label("Call \(phone)", systemImage: "phone") }
                        }
                        if let url = place.url {
                            Link(destination: url) { Label("Website", systemImage: "safari") }
                        }
                        Link(destination: MapLinks.googleMaps(place.coordinate)) {
                            Label("Open in Google Maps", systemImage: "map")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(height: 22)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }
}
