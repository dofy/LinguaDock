import AVFoundation
import Combine
import NaturalLanguage

@MainActor
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum Content {
        case source, translation
    }

    @Published private(set) var activeContent: Content?
    @Published var errorMessage: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String, language: String?, content: Content) {
        if activeContent == content {
            stop()
            return
        }
        stop()
        errorMessage = nil
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let code = Self.voiceLanguage(for: text, language: language)
        guard let voice = AVSpeechSynthesisVoice(language: code) else {
            errorMessage = String(localized: "speech.voice.unavailable",
                                  defaultValue: "No system voice is available for this language. Add a voice in System Settings → Accessibility.")
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utteranceID = ObjectIdentifier(utterance)
        activeContent = content
        synthesizer.speak(utterance)
    }

    func stop() {
        utteranceID = nil
        activeContent = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func voiceLanguage(for text: String, language: String?) -> String {
        let code = language ?? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
            ?? AVSpeechSynthesisVoice.currentLanguageCode()
        switch code {
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        default: return code
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didFinish utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didCancel utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    private nonisolated func finished(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, utteranceID == id else { return }
            utteranceID = nil
            activeContent = nil
        }
    }
}
