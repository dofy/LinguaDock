import XCTest
@testable import LinguaDock

final class TranslationDirectionTests: XCTestCase {
    func testChineseTextTranslatesToEnglish() {
        XCTAssertEqual(
            TranslationDirection.detect(for: "这是一个本地翻译工具。"),
            .chineseToEnglish
        )
    }

    func testEnglishTextTranslatesToChinese() {
        XCTAssertEqual(
            TranslationDirection.detect(for: "A local-first translation utility."),
            .otherToChinese
        )
    }

    func testMixedChineseSentenceTranslatesToEnglish() {
        XCTAssertEqual(
            TranslationDirection.detect(for: "请 review 这个 pull request"),
            .chineseToEnglish
        )
    }
}
