import AVFoundation

/// Voice guidance in English, Arabic or French.
final class SpeechGuide {
    private let synthesizer = AVSpeechSynthesizer()
    var language: VoiceLanguage = .english
    var isEnabled = true

    init() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .voicePrompt,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        )
    }

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Phrases

    func inDistance(_ meters: Double, _ instruction: String) -> String {
        let d = Format.spokenDistance(meters, language: language)
        switch language {
        case .english: return "In \(d), \(instruction)"
        case .arabic: return "بعد \(d)، \(instruction)"
        case .french: return "Dans \(d), \(instruction)"
        }
    }

    func arrived(_ name: String) -> String {
        switch language {
        case .english: return "You have arrived at \(name)"
        case .arabic: return "لقد وصلت إلى \(name)"
        case .french: return "Vous êtes arrivé à \(name)"
        }
    }

    func hazardAhead(_ type: HazardType, _ meters: Double) -> String {
        let d = Format.spokenDistance(meters, language: language)
        let name = type.spokenName(language: language)
        switch language {
        case .english: return "Caution, \(name) reported ahead in \(d)"
        case .arabic: return "انتبه، \(name) على بعد \(d)"
        case .french: return "Attention, \(name) signalé dans \(d)"
        }
    }

    func starting(_ name: String) -> String {
        switch language {
        case .english: return "Starting route to \(name)"
        case .arabic: return "بدء الملاحة إلى \(name)"
        case .french: return "Départ vers \(name)"
        }
    }

    var rerouting: String {
        switch language {
        case .english: "Rerouting"
        case .arabic: "جارٍ إعادة حساب المسار"
        case .french: "Recalcul de l'itinéraire"
        }
    }
}
