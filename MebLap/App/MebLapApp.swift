import SwiftUI

@main
struct MebLapApp: App {
    @State private var location = LocationManager()
    @State private var hazards = HazardStore()
    @State private var saved = SavedPlacesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(location)
                .environment(hazards)
                .environment(saved)
                .onAppear { location.requestPermission() }
        }
    }
}
