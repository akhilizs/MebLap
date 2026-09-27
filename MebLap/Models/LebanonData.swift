import CoreLocation
import MapKit

// MARK: - Geography

enum LebanonGeo {
    static let center = CLLocationCoordinate2D(latitude: 33.87, longitude: 35.86)
    static let region = MKCoordinateRegion(
        center: center,
        span: MKCoordinateSpan(latitudeDelta: 1.9, longitudeDelta: 1.6)
    )
    static let beirut = CLLocationCoordinate2D(latitude: 33.8938, longitude: 35.5018)

    /// Rough bounding box of Lebanon, used to keep search results local.
    static func contains(_ c: CLLocationCoordinate2D) -> Bool {
        (33.04...34.72).contains(c.latitude) && (35.09...36.65).contains(c.longitude)
    }
}

enum Governorate: String, Codable, CaseIterable {
    case beirut = "Beirut"
    case mountLebanon = "Mount Lebanon"
    case north = "North"
    case akkar = "Akkar"
    case bekaa = "Bekaa"
    case baalbekHermel = "Baalbek-Hermel"
    case south = "South"
    case nabatieh = "Nabatieh"
}

enum PlaceCategory: String, Codable {
    case city, landmark, hospital, border, airport, port, university, mall, ski, historic, nature

    var symbol: String {
        switch self {
        case .city: "building.2.fill"
        case .landmark: "star.fill"
        case .hospital: "cross.case.fill"
        case .border: "flag.fill"
        case .airport: "airplane"
        case .port: "ferry.fill"
        case .university: "graduationcap.fill"
        case .mall: "bag.fill"
        case .ski: "figure.skiing.downhill"
        case .historic: "building.columns.fill"
        case .nature: "leaf.fill"
        }
    }

    var label: String {
        switch self {
        case .city: "Town"
        case .landmark: "Landmark"
        case .hospital: "Hospital"
        case .border: "Border crossing"
        case .airport: "Airport"
        case .port: "Port"
        case .university: "University"
        case .mall: "Shopping"
        case .ski: "Ski resort"
        case .historic: "Historic site"
        case .nature: "Nature"
        }
    }
}

struct LebanonPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let nameAr: String
    let altNames: [String]
    let category: PlaceCategory
    let governorate: Governorate
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Every spelling this place is known by, normalised for matching.
    var searchKeys: [String] {
        ([name, nameAr] + altNames).map(TextNormalizer.normalize)
    }
}

private func p(_ id: String, _ name: String, _ ar: String, _ alt: [String] = [],
               _ cat: PlaceCategory, _ gov: Governorate, _ lat: Double, _ lon: Double) -> LebanonPlace {
    LebanonPlace(id: id, name: name, nameAr: ar, altNames: alt, category: cat,
                 governorate: gov, latitude: lat, longitude: lon)
}

enum LebanonData {
    /// Built-in gazetteer: towns, landmarks and key destinations, with the
    /// Arabic name and the common alternative spellings Lebanese drivers use.
    static let places: [LebanonPlace] = [
        // Towns & cities
        p("beirut", "Beirut", "بيروت", ["Bayrut", "Beyrouth"], .city, .beirut, 33.8938, 35.5018),
        p("tripoli", "Tripoli", "طرابلس", ["Trablos", "Trablous", "Tarablus"], .city, .north, 34.4367, 35.8497),
        p("sidon", "Sidon", "صيدا", ["Saida", "Saïda"], .city, .south, 33.5631, 35.3689),
        p("tyre", "Tyre", "صور", ["Sour", "Sur"], .city, .south, 33.2705, 35.2038),
        p("zahle", "Zahle", "زحلة", ["Zahleh", "Zahlé"], .city, .bekaa, 33.8463, 35.9020),
        p("baalbek", "Baalbek", "بعلبك", ["Baalbeck"], .city, .baalbekHermel, 34.0047, 36.2110),
        p("byblos", "Byblos", "جبيل", ["Jbeil", "Jbail", "Jubayl"], .city, .mountLebanon, 34.1230, 35.6519),
        p("jounieh", "Jounieh", "جونيه", ["Jounie", "Junieh"], .city, .mountLebanon, 33.9808, 35.6178),
        p("nabatieh", "Nabatieh", "النبطية", ["Nabatiyeh", "Nabatiye"], .city, .nabatieh, 33.3772, 35.4839),
        p("batroun", "Batroun", "البترون", ["Batrun"], .city, .north, 34.2553, 35.6581),
        p("aley", "Aley", "عاليه", ["Alay", "Aleih"], .city, .mountLebanon, 33.8055, 35.6000),
        p("bhamdoun", "Bhamdoun", "بحمدون", [], .city, .mountLebanon, 33.8000, 35.6500),
        p("broummana", "Broummana", "برمانا", ["Brummana", "Brumana"], .city, .mountLebanon, 33.8828, 35.6206),
        p("chtaura", "Chtaura", "شتورة", ["Shtaura", "Chtoura"], .city, .bekaa, 33.8150, 35.8500),
        p("halba", "Halba", "حلبا", [], .city, .akkar, 34.5428, 36.0797),
        p("hermel", "Hermel", "الهرمل", [], .city, .baalbekHermel, 34.3943, 36.3847),
        p("marjayoun", "Marjayoun", "مرجعيون", ["Marjeyoun"], .city, .nabatieh, 33.3608, 35.5911),
        p("bint-jbeil", "Bint Jbeil", "بنت جبيل", [], .city, .nabatieh, 33.1211, 35.4336),
        p("jezzine", "Jezzine", "جزين", ["Jezine"], .city, .south, 33.5436, 35.5847),
        p("ehden", "Ehden", "إهدن", [], .city, .north, 34.2910, 35.9950),
        p("bcharre", "Bcharre", "بشري", ["Bsharri", "Bsharre"], .city, .north, 34.2508, 36.0106),
        p("zgharta", "Zgharta", "زغرتا", [], .city, .north, 34.3975, 35.8942),
        p("chekka", "Chekka", "شكا", [], .city, .north, 34.3228, 35.7297),
        p("damour", "Damour", "الدامور", [], .city, .mountLebanon, 33.7300, 35.4500),
        p("deir-el-qamar", "Deir el Qamar", "دير القمر", ["Deir al Qamar"], .historic, .mountLebanon, 33.6967, 35.5617),
        p("rashaya", "Rashaya", "راشيا", ["Rachaya"], .city, .bekaa, 33.5000, 35.8436),
        p("faraya", "Faraya", "فاريا", ["Faqra"], .city, .mountLebanon, 33.9990, 35.8230),
        p("baabda", "Baabda", "بعبدا", [], .city, .mountLebanon, 33.8339, 35.5442),
        p("dbayeh", "Dbayeh", "ضبية", ["Dbayyeh"], .city, .mountLebanon, 33.9380, 35.5870),
        p("antelias", "Antelias", "انطلياس", [], .city, .mountLebanon, 33.9130, 35.5870),
        p("jal-el-dib", "Jal el Dib", "جل الديب", [], .city, .mountLebanon, 33.9080, 35.5770),
        p("khalde", "Khalde", "خلدة", ["Khaldeh"], .city, .mountLebanon, 33.7810, 35.4700),

        // Beirut landmarks
        p("bey-airport", "Beirut–Rafic Hariri International Airport", "مطار رفيق الحريري الدولي", ["Airport", "BEY", "Matar"], .airport, .mountLebanon, 33.8209, 35.4884),
        p("beirut-port", "Port of Beirut", "مرفأ بيروت", ["Marfa"], .port, .beirut, 33.9019, 35.5192),
        p("martyrs-square", "Martyrs' Square", "ساحة الشهداء", ["Downtown", "Wasat el Balad", "Beirut Central District"], .landmark, .beirut, 33.8958, 35.5075),
        p("raouche", "Raouche (Pigeon Rocks)", "الروشة", ["Rawcheh", "Pigeon Rock"], .landmark, .beirut, 33.8897, 35.4700),
        p("hamra", "Hamra Street", "شارع الحمراء", ["Hamra"], .landmark, .beirut, 33.8961, 35.4828),
        p("corniche", "Beirut Corniche", "كورنيش بيروت", ["Manara", "Ain el Mreisseh"], .landmark, .beirut, 33.9010, 35.4800),
        p("mar-mikhael", "Mar Mikhael", "مار مخايل", ["Gemmayzeh"], .landmark, .beirut, 33.8980, 35.5260),
        p("aub", "American University of Beirut", "الجامعة الأميركية في بيروت", ["AUB"], .university, .beirut, 33.9000, 35.4800),
        p("usj", "Université Saint-Joseph", "جامعة القديس يوسف", ["USJ"], .university, .beirut, 33.8890, 35.5140),
        p("lau-byblos", "LAU Byblos Campus", "الجامعة اللبنانية الأميركية - جبيل", ["LAU"], .university, .mountLebanon, 34.1150, 35.6740),
        p("abc-achrafieh", "ABC Achrafieh", "إي بي سي الأشرفية", ["ABC"], .mall, .beirut, 33.8886, 35.5195),
        p("city-centre", "City Centre Beirut (Hazmieh)", "سيتي سنتر الحازمية", ["City Center"], .mall, .mountLebanon, 33.8567, 35.5389),
        p("le-mall-dbayeh", "Le Mall Dbayeh", "لو مول ضبية", [], .mall, .mountLebanon, 33.9384, 35.5895),

        // Hospitals
        p("aubmc", "AUB Medical Center", "المركز الطبي في الجامعة الأميركية", ["AUBMC"], .hospital, .beirut, 33.8973, 35.4856),
        p("hotel-dieu", "Hôtel-Dieu de France", "مستشفى أوتيل ديو", ["Hotel Dieu"], .hospital, .beirut, 33.8810, 35.5190),
        p("rhuh", "Rafik Hariri University Hospital", "مستشفى رفيق الحريري الجامعي", ["RHUH", "Beirut Governmental Hospital"], .hospital, .beirut, 33.8622, 35.4932),
        p("st-george", "St. George Hospital (Roum)", "مستشفى القديس جاورجيوس", ["Roum", "Rum hospital"], .hospital, .beirut, 33.8928, 35.5200),
        p("cmc", "Clemenceau Medical Center", "مركز كليمنصو الطبي", ["CMC"], .hospital, .beirut, 33.8960, 35.4880),

        // Tourism & nature
        p("jeita", "Jeita Grotto", "مغارة جعيتا", ["Jeita"], .nature, .mountLebanon, 33.9436, 35.6411),
        p("harissa", "Our Lady of Lebanon, Harissa", "سيدة لبنان - حريصا", ["Harissa"], .landmark, .mountLebanon, 33.9818, 35.6515),
        p("casino", "Casino du Liban", "كازينو لبنان", [], .landmark, .mountLebanon, 33.9721, 35.6069),
        p("beiteddine", "Beiteddine Palace", "قصر بيت الدين", ["Beit ed-Dine"], .historic, .mountLebanon, 33.6953, 35.5800),
        p("anjar", "Anjar Ruins", "آثار عنجر", ["Anjar"], .historic, .bekaa, 33.7264, 35.9336),
        p("baalbek-temples", "Baalbek Temples", "قلعة بعلبك", ["Heliopolis"], .historic, .baalbekHermel, 34.0069, 36.2039),
        p("byblos-citadel", "Byblos Citadel", "قلعة جبيل", [], .historic, .mountLebanon, 34.1195, 35.6454),
        p("cedars-god", "Cedars of God (Arz el Rab)", "أرز الرب", ["Arz", "The Cedars", "Arz el Rab"], .nature, .north, 34.2440, 36.0480),
        p("barouk", "Shouf Cedar Reserve (Barouk)", "محمية أرز الشوف - الباروك", ["Barouk", "Chouf cedars"], .nature, .mountLebanon, 33.6960, 35.6880),
        p("qadisha", "Qadisha Valley", "وادي قاديشا", ["Kadisha", "Wadi Qadisha"], .nature, .north, 34.2430, 35.9500),
        p("tannourine", "Tannourine Cedars", "أرز تنورين", [], .nature, .north, 34.2080, 35.9180),

        // Ski
        p("mzaar", "Mzaar Kfardebian Ski Resort", "مزار كفرذبيان", ["Mzaar", "Kfardebian", "Faraya Mzaar"], .ski, .mountLebanon, 34.0010, 35.8470),
        p("cedars-ski", "The Cedars Ski Resort", "منتجع الأرز للتزلج", [], .ski, .north, 34.2440, 36.0550),
        p("laqlouq", "Laqlouq", "اللقلوق", ["Laklouk"], .ski, .mountLebanon, 34.1330, 35.8830),
        p("zaarour", "Zaarour Club", "الزعرور", ["Zaarour"], .ski, .mountLebanon, 33.9010, 35.7440),

        // Borders
        p("masnaa", "Masnaa Border Crossing", "معبر المصنع", ["Masnaa", "Masna", "Syria border"], .border, .bekaa, 33.7010, 36.0760),
        p("arida", "Arida Border Crossing", "معبر العريضة", ["Arida", "Areeda"], .border, .akkar, 34.6360, 35.9740),
        p("aboudieh", "Aboudieh Border Crossing", "معبر العبودية", ["Aboudiyeh", "Dabousieh"], .border, .akkar, 34.6320, 36.1090),
        p("qaa", "Qaa / Jousieh Border Crossing", "معبر القاع - جوسيه", ["Qaa", "Jousieh"], .border, .baalbekHermel, 34.3860, 36.5530),
    ]

    static let emergencyContacts: [EmergencyContact] = [
        EmergencyContact(name: "Internal Security Forces (Police)", nameAr: "قوى الأمن الداخلي", number: "112", symbol: "shield.lefthalf.filled"),
        EmergencyContact(name: "Lebanese Red Cross (Ambulance)", nameAr: "الصليب الأحمر اللبناني", number: "140", symbol: "cross.case.fill"),
        EmergencyContact(name: "Civil Defense", nameAr: "الدفاع المدني", number: "125", symbol: "flame.fill"),
        EmergencyContact(name: "Fire Brigade (Beirut)", nameAr: "فوج إطفاء بيروت", number: "175", symbol: "fire.extinguisher.fill"),
        EmergencyContact(name: "Ministry of Public Health Hotline", nameAr: "الخط الساخن لوزارة الصحة", number: "1214", symbol: "stethoscope"),
    ]

    /// High-altitude roads that close, need chains or fog up in winter.
    /// Coordinates and elevations are approximate.
    static let mountainPasses: [MountainPass] = [
        MountainPass(id: "dahr-el-baidar", name: "Dahr el Baidar", nameAr: "ضهر البيدر",
                     road: "Beirut – Chtaura highway", elevation: 1556, latitude: 33.8114, longitude: 35.7753),
        MountainPass(id: "sofar", name: "Sofar", nameAr: "صوفر",
                     road: "Old Beirut – Damascus road (Aley – Sofar)", elevation: 1300, latitude: 33.8010, longitude: 35.7040),
        MountainPass(id: "tarshish", name: "Tarshish – Zahle", nameAr: "ترشيش - زحلة",
                     road: "Metn – Zahle mountain road", elevation: 1450, latitude: 33.8830, longitude: 35.7870),
        MountainPass(id: "dhour-choueir", name: "Dhour El Choueir", nameAr: "ضهور الشوير",
                     road: "Bikfaya – Dhour El Choueir", elevation: 1250, latitude: 33.9110, longitude: 35.7120),
        MountainPass(id: "mzaar", name: "Faraya – Mzaar", nameAr: "فاريا - مزار كفرذبيان",
                     road: "Faraya – Kfardebian – Mzaar", elevation: 1850, latitude: 34.0020, longitude: 35.8440),
        MountainPass(id: "laqlouq", name: "Laqlouq", nameAr: "اللقلوق",
                     road: "Aaqoura – Laqlouq – Tannourine", elevation: 1700, latitude: 34.1330, longitude: 35.8830),
        MountainPass(id: "cedars", name: "Bcharre – Cedars", nameAr: "بشري - الأرز",
                     road: "Bcharre – Cedars road", elevation: 1950, latitude: 34.2440, longitude: 36.0480),
        MountainPass(id: "ainata", name: "Cedars – Ainata", nameAr: "الأرز - عيناتا",
                     road: "Cedars – Ainata – Deir el Ahmar (usually closed in winter)", elevation: 2600, latitude: 34.2140, longitude: 36.1030),
        MountainPass(id: "barouk", name: "Barouk – Maasser el Chouf", nameAr: "الباروك - معاصر الشوف",
                     road: "Chouf – West Bekaa crossing", elevation: 1800, latitude: 33.7000, longitude: 35.7050),
    ]

    static func nearestPlace(to coordinate: CLLocationCoordinate2D) -> (place: LebanonPlace, distance: CLLocationDistance)? {
        places
            .map { ($0, GeoMath.distance(coordinate, $0.coordinate)) }
            .min { $0.1 < $1.1 }
            .map { (place: $0.0, distance: $0.1) }
    }

    /// Lebanese addressing is landmark-based — describe a spot relative to the nearest known place.
    static func landmarkDescription(for coordinate: CLLocationCoordinate2D) -> String? {
        guard let nearest = nearestPlace(to: coordinate) else { return nil }
        if nearest.distance < 300 { return "At \(nearest.place.name)" }
        let bearing = GeoMath.bearing(from: nearest.place.coordinate, to: coordinate)
        return "\(Format.distance(nearest.distance)) \(GeoMath.compassName(bearing)) of \(nearest.place.name)"
    }
}

struct EmergencyContact: Identifiable, Hashable {
    var id: String { number }
    let name: String
    let nameAr: String
    let number: String
    let symbol: String
}

struct MountainPass: Identifiable, Hashable {
    let id: String
    let name: String
    let nameAr: String
    let road: String
    let elevation: Int
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
