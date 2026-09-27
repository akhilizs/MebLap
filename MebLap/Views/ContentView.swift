import SwiftUI
import UIKit
import MapKit

enum ActiveSheet: Identifiable {
    case search
    case report(CLLocationCoordinate2D?)
    case emergency
    case roadConditions
    case tripCost
    case settings
    case saved
    case hazard(UUID)
    case pass(String)

    var id: String {
        switch self {
        case .search: "search"
        case .report: "report"
        case .emergency: "emergency"
        case .roadConditions: "roadConditions"
        case .tripCost: "tripCost"
        case .settings: "settings"
        case .saved: "saved"
        case .hazard(let id): "hazard-\(id)"
        case .pass(let id): "pass-\(id)"
        }
    }
}

enum PinMode {
    case none, destination, hazard
}

struct ContentView: View {
    @Environment(LocationManager.self) private var location
    @Environment(HazardStore.self) private var hazards
    @Environment(SavedPlacesStore.self) private var saved

    @State private var vm = MapViewModel()
    @State private var roadConditions = RoadConditionsService()
    @State private var nearby = SearchService()
    @State private var sheet: ActiveSheet?
    @State private var pinMode = PinMode.none
    @State private var isRerouting = false

    @AppStorage(SettingsKey.mapStyle) private var mapStyle = MapStyleOption.standard.rawValue
    @AppStorage(SettingsKey.showTraffic) private var showTraffic = true
    @AppStorage(SettingsKey.showHazards) private var showHazards = true
    @AppStorage(SettingsKey.showPasses) private var showPasses = false
    @AppStorage(SettingsKey.showLandmarks) private var showLandmarks = false
    @AppStorage(SettingsKey.avoidHazards) private var avoidHazards = true
    @AppStorage(SettingsKey.avoidTolls) private var avoidTolls = false
    @AppStorage(SettingsKey.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKey.voiceLanguage) private var voiceLanguage = VoiceLanguage.english.rawValue

    private var language: VoiceLanguage { VoiceLanguage(rawValue: voiceLanguage) ?? .english }
    private var userCoordinate: CLLocationCoordinate2D? { location.location?.coordinate }

    var body: some View {
        map
            .overlay(alignment: .top) { topOverlay }
            .overlay(alignment: .trailing) {
                if vm.navigation == nil { sideButtons }
            }
            .safeAreaInset(edge: .bottom) { bottomPanel }
            .sheet(item: $sheet) { sheetContent($0) }
            .onChange(of: location.location) { _, newLocation in
                handleLocationUpdate(newLocation)
            }
            .onChange(of: vm.selection) { _, tag in
                handleSelection(tag)
            }
            .onChange(of: hazards.reports) {
                vm.navigation?.updateHazards(hazards.active)
            }
            .onChange(of: vm.navigation == nil) { _, notNavigating in
                location.setNavigating(!notNavigating)
                UIApplication.shared.isIdleTimerDisabled = !notNavigating
            }
            .onChange(of: avoidHazards) { _, avoid in
                let best = avoid
                    ? vm.routeOptions.min { $0.adjustedTime < $1.adjustedTime }
                    : vm.routeOptions.min { $0.route.expectedTravelTime < $1.route.expectedTravelTime }
                vm.selectedRouteID = best?.id
            }
            .onChange(of: avoidTolls) {
                if !vm.routeOptions.isEmpty { requestDirections() }
            }
            .task {
                hazards.purgeExpired()
                await roadConditions.refreshIfStale()
            }
    }

    // MARK: Map

    private var map: some View {
        MapReader { proxy in
            Map(position: $vm.position, selection: $vm.selection) {
                UserAnnotation()

                if showLandmarks {
                    ForEach(LebanonData.places) { place in
                        Marker(place.name, systemImage: place.category.symbol, coordinate: place.coordinate)
                            .tint(.teal)
                            .tag(MapTag.place(place.id))
                    }
                }

                if showPasses {
                    ForEach(LebanonData.mountainPasses) { pass in
                        Annotation(pass.name, coordinate: pass.coordinate) {
                            PassPin(risk: roadConditions.weather[pass.id]?.assessment.risk)
                        }
                        .tag(MapTag.pass(pass.id))
                    }
                }

                ForEach(vm.routeOptions.filter { $0.id != vm.selectedRoute?.id }) { option in
                    MapPolyline(option.route.polyline)
                        .stroke(Color.gray.opacity(0.7), lineWidth: 6)
                }
                if let selected = vm.selectedRoute {
                    MapPolyline(selected.route.polyline)
                        .stroke(selected.isBlocked ? Color.lebanonRed : Color.blue, lineWidth: 8)
                }

                if showHazards {
                    ForEach(hazards.active) { report in
                        Annotation(report.type.title, coordinate: report.coordinate) {
                            HazardPin(type: report.type)
                        }
                        .tag(MapTag.hazard(report.id))
                    }
                }

                ForEach(vm.searchResults) { result in
                    Marker(result.name, systemImage: result.symbol, coordinate: result.coordinate)
                        .tint(Color.cedar)
                        .tag(MapTag.result(result.id))
                }

                if let destination = vm.destination {
                    Marker(destination.name, systemImage: destination.symbol, coordinate: destination.coordinate)
                        .tint(Color.lebanonRed)
                        .tag(MapTag.destination)
                }
            }
            .mapStyle((MapStyleOption(rawValue: mapStyle) ?? .standard).style(traffic: showTraffic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                vm.mapCenter = context.region.center
            }
            .gesture(
                SpatialTapGesture().onEnded { value in
                    guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                    handleMapTap(coordinate)
                },
                including: pinMode == .none ? .subviews : .all
            )
        }
    }

    // MARK: Overlays

    @ViewBuilder
    private var topOverlay: some View {
        VStack(spacing: 8) {
            if let session = vm.navigation {
                NavigationHUD(session: session, isRerouting: isRerouting)
            } else {
                searchBar
            }
            if pinMode != .none {
                Label(pinMode == .hazard ? "Tap the map where the hazard is" : "Tap the map to drop a pin",
                      systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thickMaterial, in: Capsule())
                    .onTapGesture { pinMode = .none }
            }
            if let error = vm.routeError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.lebanonRed, in: Capsule())
                    .onTapGesture { vm.routeError = nil }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button { sheet = .search } label: {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("Search Lebanon · ابحث").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            CircleButton(symbol: "person.crop.circle") { sheet = .settings }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    private var sideButtons: some View {
        VStack(spacing: 10) {
            Menu {
                Picker("Map style", selection: $mapStyle) {
                    ForEach(MapStyleOption.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Live traffic", isOn: $showTraffic)
                Toggle("Road hazards", isOn: $showHazards)
                Toggle("Mountain passes", isOn: $showPasses)
                Toggle("Lebanon landmarks", isOn: $showLandmarks)
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            CircleButton(symbol: "exclamationmark.bubble.fill", tint: .orange) {
                sheet = .report(userCoordinate)
            }
            CircleButton(symbol: "mappin.and.ellipse", tint: pinMode == .destination ? .cedar : .primary) {
                pinMode = pinMode == .destination ? .none : .destination
            }
            CircleButton(symbol: "snowflake", tint: .cyan) { sheet = .roadConditions }
            CircleButton(symbol: "star.fill", tint: .yellow) { sheet = .saved }
            CircleButton(symbol: "sos", background: .lebanonRed) { sheet = .emergency }
        }
        .padding(.trailing, 12)
        .padding(.top, 120)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let session = vm.navigation {
            NavigationBottomBar(
                session: session,
                onReport: { sheet = .report(userCoordinate) },
                onEnd: { vm.endNavigation() }
            )
        } else if let destination = vm.destination, vm.isCalculating || !vm.routeOptions.isEmpty {
            RoutePanel(
                vm: vm,
                destination: destination,
                avoidHazards: $avoidHazards,
                avoidTolls: $avoidTolls,
                onStart: {
                    vm.startNavigation(hazards: hazards, language: language, voice: voiceEnabled)
                },
                onTripCost: { sheet = .tripCost },
                onClose: { vm.routeOptions = []; vm.selectedRouteID = nil }
            )
        } else if let destination = vm.destination {
            PlaceCard(
                place: destination,
                userLocation: userCoordinate,
                nearbyHazards: hazards.hazards(near: destination.coordinate, within: 2000).count,
                onDirections: { requestDirections() },
                onClose: { vm.clear() }
            )
        } else if !vm.searchResults.isEmpty {
            resultsStrip
        } else {
            quickBar
        }
    }

    private var resultsStrip: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(vm.searchResults.count) results nearby").font(.headline)
                    Spacer()
                    Button { vm.clear() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.searchResults.prefix(12)) { place in
                            Button { select(place) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(place.name, systemImage: place.symbol).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    if let user = userCoordinate {
                                        Text(Format.distance(GeoMath.distance(user, place.coordinate)))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(width: 170, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var quickBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let home = saved.home {
                    Chip(title: "Home", symbol: "house.fill") { go(to: home) }
                }
                if let work = saved.work {
                    Chip(title: "Work", symbol: "briefcase.fill") { go(to: work) }
                }
                Chip(title: "Fuel nearby", symbol: "fuelpump.fill") { searchNearby(.gas) }
                Chip(title: "Hospitals", symbol: "cross.case.fill", tint: .lebanonRed) { searchNearby(.hospital) }
                Chip(title: "Road conditions", symbol: "mountain.2.fill", tint: .cyan) { sheet = .roadConditions }
                Chip(title: "Report", symbol: "exclamationmark.bubble.fill", tint: .orange) {
                    sheet = .report(userCoordinate)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .search:
            SearchView(center: userCoordinate ?? vm.mapCenter, userLocation: userCoordinate,
                       onSelect: { select($0) },
                       onResults: { vm.showResults($0) })
        case .report(let coordinate):
            ReportHazardView(
                coordinate: coordinate ?? userCoordinate ?? vm.mapCenter,
                quickMode: vm.navigation != nil,
                onPickOnMap: { pinMode = .hazard }
            )
            .presentationDetents([.medium, .large])
        case .emergency:
            EmergencyView(location: location.location)
        case .roadConditions:
            RoadConditionsView(service: roadConditions, showOnMap: $showPasses) { pass in
                showPasses = true
                withAnimation {
                    vm.position = .region(MKCoordinateRegion(center: pass.coordinate,
                                                             latitudinalMeters: 12_000, longitudinalMeters: 12_000))
                }
            }
        case .tripCost:
            TripCostView(distance: vm.selectedRoute?.route.distance ?? 0,
                         duration: vm.selectedRoute?.route.expectedTravelTime ?? 0)
        case .settings:
            SettingsView()
        case .saved:
            SavedPlacesView(userLocation: userCoordinate, currentPlace: vm.destination) { select($0) }
        case .hazard(let id):
            HazardDetailView(id: id)
                .presentationDetents([.medium])
        case .pass(let id):
            if let pass = LebanonData.mountainPasses.first(where: { $0.id == id }) {
                PassDetailView(pass: pass, weather: roadConditions.weather[pass.id]) {
                    go(to: MapPlace(id: "pass-\(pass.id)", name: pass.name, subtitle: pass.road,
                                    coordinate: pass.coordinate, symbol: "mountain.2.fill"))
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: Actions

    private func select(_ place: MapPlace) {
        saved.addRecent(place)
        vm.show(place)
    }

    private func go(to place: MapPlace) {
        select(place)
        requestDirections()
    }

    private func requestDirections() {
        Task {
            await vm.calculateRoutes(from: userCoordinate, hazards: hazards,
                                     avoidHazards: avoidHazards, avoidTolls: avoidTolls)
        }
    }

    private func searchNearby(_ category: QuickCategory) {
        Task {
            let results = await nearby.search(category: category, near: userCoordinate ?? vm.mapCenter)
            if results.isEmpty {
                vm.routeError = "No \(category.title.lowercased()) found nearby."
            } else {
                vm.showResults(results)
            }
        }
    }

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch pinMode {
        case .none:
            return
        case .destination:
            select(.droppedPin(at: coordinate))
        case .hazard:
            sheet = .report(coordinate)
        }
        pinMode = .none
    }

    private func handleSelection(_ tag: MapTag?) {
        guard let tag else { return }
        switch tag {
        case .hazard(let id):
            sheet = .hazard(id)
        case .pass(let id):
            sheet = .pass(id)
        case .place(let id):
            if let place = LebanonData.places.first(where: { $0.id == id }) {
                select(MapPlace(place))
            }
        case .result(let id):
            if let place = vm.searchResults.first(where: { $0.id == id }) {
                select(place)
            }
        case .destination:
            break
        }
        vm.selection = nil
    }

    private func handleLocationUpdate(_ newLocation: CLLocation?) {
        guard let newLocation, let session = vm.navigation else { return }
        session.update(with: newLocation)
        if session.needsReroute && !isRerouting {
            isRerouting = true
            Task {
                await vm.reroute(from: newLocation, hazards: hazards, avoidTolls: avoidTolls, language: language)
                isRerouting = false
            }
        }
    }
}
