import Foundation
import NaturalLanguage

struct TranslationDirection: Equatable, Sendable {
    var source: TargetLanguage?
    var target: TargetLanguage

    static func resolve(source: TargetLanguage?, smart: Bool, fixed: TargetLanguage,
                        primary: TargetLanguage, fallback: TargetLanguage) -> Self {
        let target = smart
            ? (source?.isSameLanguage(as: primary) == true ? fallback : primary)
            : fixed
        return Self(source: source, target: target)
    }

    /// Uncertain input keeps the primary target. Code and URLs must not outweigh prose.
    static func detectSource(in text: String) -> TargetLanguage? {
        let prose = text
            .replacingOccurrences(of: #"(?s)```.*?(?:```|$)|`[^`\n]*`|https?://\S+"#,
                                 with: " ", options: .regularExpression)
        let letters = prose.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 2 else { return nil }
        // Very short Latin words and identifiers are too ambiguous to change direction.
        if letters.count < 4, letters.allSatisfy({ $0.isASCII }) { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(prose)
        var scores: [String: Double] = [:]
        for (language, probability) in recognizer.languageHypotheses(withMaximum: 5) {
            let family = language.rawValue.split(separator: "-").first.map(String.init) ?? language.rawValue
            scores[family, default: 0] += probability
        }
        let ranked = scores.sorted { $0.value > $1.value }
        guard let best = ranked.first, best.value >= 0.75,
              best.value - (ranked.dropFirst().first?.value ?? 0) >= 0.2 else { return nil }
        if best.key == "zh" {
            return recognizer.dominantLanguage == .traditionalChinese ? .traditionalChinese : .simplifiedChinese
        }
        return TargetLanguage(rawValue: best.key)
    }
}
