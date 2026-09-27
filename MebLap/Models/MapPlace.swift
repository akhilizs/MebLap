import MapKit

/// A destination the user can look at, save or navigate to — from the
/// built-in gazetteer, Apple Maps search, a saved place or a dropped pin.
struct MapPlace: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var symbol: String
    var phone: String?
    var url: URL?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.phoneNumber = phone
        item.url = url
        return item
    }

    init(id: String, name: String, subtitle: String, coordinate: CLLocationCoordinate2D,
         symbol: String = "mappin", phone: String? = nil, url: URL? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.symbol = symbol
        self.phone = phone
        self.url = url
    }

    init(_ place: LebanonPlace) {
        self.init(id: "lb-\(place.id)", name: place.name,
                  subtitle: "\(place.nameAr) · \(place.category.label), \(place.governorate.rawValue)",
                  coordinate: place.coordinate, symbol: place.category.symbol)
    }

    init(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        let name = item.name ?? "Unnamed place"
        let address = [item.placemark.thoroughfare, item.placemark.locality, item.placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        self.init(id: String(format: "mk-%.5f,%.5f-%@", c.latitude, c.longitude, name),
                  name: name,
                  subtitle: address.isEmpty ? (LebanonData.landmarkDescription(for: c) ?? "") : address,
                  coordinate: c,
                  symbol: Self.symbol(for: item.pointOfInterestCategory),
                  phone: item.phoneNumber,
                  url: item.url)
    }

    static func droppedPin(at c: CLLocationCoordinate2D) -> MapPlace {
        MapPlace(id: String(format: "pin-%.5f,%.5f", c.latitude, c.longitude),
                 name: "Dropped pin",
                 subtitle: LebanonData.landmarkDescription(for: c) ?? String(format: "%.5f, %.5f", c.latitude, c.longitude),
                 coordinate: c, symbol: "mappin")
    }

    static func symbol(for category: MKPointOfInterestCategory?) -> String {
        switch category {
        case .gasStation?: "fuelpump.fill"
        case .hospital?: "cross.case.fill"
        case .pharmacy?: "pills.fill"
        case .parking?: "parkingsign"
        case .atm?, .bank?: "banknote.fill"
        case .restaurant?: "fork.knife"
        case .cafe?: "cup.and.saucer.fill"
        case .evCharger?: "bolt.car.fill"
        case .police?: "shield.lefthalf.filled"
        case .school?, .university?: "graduationcap.fill"
        case .hotel?: "bed.double.fill"
        case .store?: "bag.fill"
        case .airport?: "airplane"
        case .beach?: "beach.umbrella.fill"
        default: "mappin"
        }
    }
}
