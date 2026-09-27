import Foundation

enum Format {
    static func distance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int((meters / 10).rounded() * 10)) m"
        }
        return meters < 10_000
            ? String(format: "%.1f km", meters / 1000)
            : "\(Int((meters / 1000).rounded())) km"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    static func arrival(after seconds: TimeInterval) -> String {
        Date().addingTimeInterval(seconds).formatted(date: .omitted, time: .shortened)
    }

    static func lbp(_ value: Double) -> String {
        // Round to the nearest 1,000 — nobody hands over smaller notes.
        let rounded = (value / 1000).rounded() * 1000
        return rounded.formatted(.number.grouping(.automatic).precision(.fractionLength(0))) + " LBP"
    }

    static func usd(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// Distance phrased for speech in the chosen language.
    static func spokenDistance(_ meters: Double, language: VoiceLanguage) -> String {
        if meters >= 1000 {
            let km = (meters / 100).rounded() / 10
            let value = km == km.rounded() ? "\(Int(km))" : String(format: "%.1f", km)
            switch language {
            case .english: return "\(value) kilometers"
            case .arabic: return "\(value) كيلومتر"
            case .french: return "\(value.replacingOccurrences(of: ".", with: ",")) kilomètres"
            }
        }
        let m = max(10, Int((meters / 50).rounded() * 50))
        switch language {
        case .english: return "\(m) meters"
        case .arabic: return "\(m) متر"
        case .french: return "\(m) mètres"
        }
    }
}

enum TextNormalizer {
    /// Lower-cases, strips accents and Arabic diacritics, and drops common
    /// prefixes so "El-Mina", "al mina" and "Mina" all match.
    static func normalize(_ s: String) -> String {
        var t = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        t = t.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        // Arabic: unify alef forms, taa marbuta and alef maqsura
        let arabicMap: [Character: Character] = ["أ": "ا", "إ": "ا", "آ": "ا", "ة": "ه", "ى": "ي"]
        t = String(t.map { arabicMap[$0] ?? $0 })
        let words = t.split(separator: " ").map(String.init)
        let prefixes: Set<String> = ["el", "al", "al-", "the"]
        let filtered = words.filter { !prefixes.contains($0) }
        return filtered.joined(separator: " ")
    }
}
