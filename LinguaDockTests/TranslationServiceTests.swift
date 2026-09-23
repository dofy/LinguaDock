import XCTest
@testable import LinguaDock

final class TranslationServiceTests: XCTestCase {
    func testBuildsOllamaEndpoint() throws {
        XCTAssertEqual(
            try TranslationService.endpoint(baseURL: "http://localhost:11434/", path: "api/chat").absoluteString,
            "http://localhost:11434/api/chat"
        )
    }

    func testPreservesOpenAIBasePath() throws {
        XCTAssertEqual(
            try TranslationService.endpoint(baseURL: "https://example.com/v1", path: "chat/completions").absoluteString,
            "https://example.com/v1/chat/completions"
        )
    }

    // MARK: - 定界 prompt
    //
    // 裸发时正文首行若是 "User" 这类词会被模型读成对话角色标记、整行丢掉，
    // 定界说明是唯一修法，所以它必须出现在 delimited prompt 里、且不污染裸发版本。

    func testDelimitedPromptExplainsTheSourceTags() {
        let prompt = TranslationService.systemPrompt(targetLanguage: .simplifiedChinese, delimited: true)

        XCTAssertTrue(prompt.contains("<source>"))
        XCTAssertTrue(prompt.contains("</source>"))
        XCTAssertTrue(prompt.contains("omit nothing"))
    }

    /// 两个客户端(macOS app 与 Raycast 扩展)发的是同一个 prompt。列表标记那一行
    /// 曾经只有 `Raycast/src/api.ts` 有，导致同一段文本在两边译出不同排版。
    func testPromptRestoresFlattenedListMarkers() {
        let prompt = TranslationService.systemPrompt(targetLanguage: .simplifiedChinese)

        XCTAssertTrue(prompt.contains("restore each bullet, checkbox, or numbered item onto its own line"))
    }

    func testPlainPromptMentionsNoDelimiters() {
        let prompt = TranslationService.systemPrompt(targetLanguage: .simplifiedChinese, delimited: false)

        XCTAssertFalse(prompt.contains("<source>"))
    }

    func testPromptDefaultsToNoDelimiters() {
        XCTAssertEqual(
            TranslationService.systemPrompt(targetLanguage: .japanese),
            TranslationService.systemPrompt(targetLanguage: .japanese, delimited: false)
        )
    }

    func testDoesNotDuplicateFullEndpoint() throws {
        XCTAssertEqual(
            try TranslationService.endpoint(
                baseURL: "https://example.com/v1/chat/completions",
                path: "chat/completions"
            ).absoluteString,
            "https://example.com/v1/chat/completions"
        )
    }
}
