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
