import Foundation

enum TargetLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case malay = "ms"
    case turkish = "tr"
    case dutch = "nl"
    case polish = "pl"
    case ukrainian = "uk"

    static let `default`: TargetLanguage = .simplifiedChinese

    var id: String { rawValue }

    /// 选择器里显示的语言名。**不要**拿它当 prompt 用——发给模型的名字是
    /// `promptName`，必须保持英文。
    var displayName: String {
        switch self {
        case .simplifiedChinese:
            String(localized: "lang.zh-Hans", defaultValue: "Simplified Chinese")
        case .traditionalChinese:
            String(localized: "lang.zh-Hant", defaultValue: "Traditional Chinese")
        case .english:
            String(localized: "lang.en", defaultValue: "English")
        case .japanese:
            String(localized: "lang.ja", defaultValue: "Japanese")
        case .korean:
            String(localized: "lang.ko", defaultValue: "Korean")
        case .spanish:
            String(localized: "lang.es", defaultValue: "Spanish")
        case .french:
            String(localized: "lang.fr", defaultValue: "French")
        case .german:
            String(localized: "lang.de", defaultValue: "German")
        case .portuguese:
            String(localized: "lang.pt", defaultValue: "Portuguese")
        case .italian:
            String(localized: "lang.it", defaultValue: "Italian")
        case .russian:
            String(localized: "lang.ru", defaultValue: "Russian")
        case .arabic:
            String(localized: "lang.ar", defaultValue: "Arabic")
        case .hindi:
            String(localized: "lang.hi", defaultValue: "Hindi")
        case .thai:
            String(localized: "lang.th", defaultValue: "Thai")
        case .vietnamese:
            String(localized: "lang.vi", defaultValue: "Vietnamese")
        case .indonesian:
            String(localized: "lang.id", defaultValue: "Indonesian")
        case .malay:
            String(localized: "lang.ms", defaultValue: "Malay")
        case .turkish:
            String(localized: "lang.tr", defaultValue: "Turkish")
        case .dutch:
            String(localized: "lang.nl", defaultValue: "Dutch")
        case .polish:
            String(localized: "lang.pl", defaultValue: "Polish")
        case .ukrainian:
            String(localized: "lang.uk", defaultValue: "Ukrainian")
        }
    }

    var promptName: String {
        switch self {
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        case .english: "English"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .portuguese: "Portuguese"
        case .italian: "Italian"
        case .russian: "Russian"
        case .arabic: "Arabic"
        case .hindi: "Hindi"
        case .thai: "Thai"
        case .vietnamese: "Vietnamese"
        case .indonesian: "Indonesian"
        case .malay: "Malay"
        case .turkish: "Turkish"
        case .dutch: "Dutch"
        case .polish: "Polish"
        case .ukrainian: "Ukrainian"
        }
    }
}
