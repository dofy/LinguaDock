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

    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "英语"
        case .japanese: "日语"
        case .korean: "韩语"
        case .spanish: "西班牙语"
        case .french: "法语"
        case .german: "德语"
        case .portuguese: "葡萄牙语"
        case .italian: "意大利语"
        case .russian: "俄语"
        case .arabic: "阿拉伯语"
        case .hindi: "印地语"
        case .thai: "泰语"
        case .vietnamese: "越南语"
        case .indonesian: "印度尼西亚语"
        case .malay: "马来语"
        case .turkish: "土耳其语"
        case .dutch: "荷兰语"
        case .polish: "波兰语"
        case .ukrainian: "乌克兰语"
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
