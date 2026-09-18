import Foundation

enum TranslationDirection: Equatable {
    case chineseToEnglish
    case otherToChinese

    static func detect(for text: String) -> TranslationDirection {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return .otherToChinese }

        let chineseCount = scalars.filter { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x20000...0x2FA1F:
                true
            default:
                false
            }
        }.count

        return Double(chineseCount) / Double(scalars.count) >= 0.15
            ? .chineseToEnglish
            : .otherToChinese
    }

    var sourceLabel: String {
        switch self {
        case .chineseToEnglish: "中文"
        case .otherToChinese: "自动检测"
        }
    }

    var targetLabel: String {
        switch self {
        case .chineseToEnglish: "English"
        case .otherToChinese: "中文"
        }
    }

    var prompt: String {
        switch self {
        case .chineseToEnglish:
            "Translate the user's text from Chinese into natural, precise English."
        case .otherToChinese:
            "Translate the user's text into natural, precise Simplified Chinese."
        }
    }
}
