import XCTest
@testable import LinguaDock

final class TargetLanguageTests: XCTestCase {
    func testDefaultTargetLanguageIsSimplifiedChinese() {
        XCTAssertEqual(TargetLanguage.default, .simplifiedChinese)
    }

    func testLanguageIdentifiersAreUnique() {
        XCTAssertEqual(
            Set(TargetLanguage.allCases.map(\.rawValue)).count,
            TargetLanguage.allCases.count
        )
    }

    func testPromptUsesSelectedTargetLanguage() {
        let prompt = TranslationService.systemPrompt(targetLanguage: .japanese)

        XCTAssertTrue(prompt.contains("Japanese"))
        XCTAssertFalse(prompt.contains("Simplified Chinese"))
    }
}
