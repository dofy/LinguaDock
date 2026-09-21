import XCTest
@testable import LinguaDock

final class ImageTextRecognizerTests: XCTestCase {
    func testNormalizeKeepsLineBreaksBetweenLines() {
        let text = ImageTextRecognizer.normalize(lines: ["Hello world", "Second line"])

        XCTAssertEqual(text, "Hello world\nSecond line")
    }

    func testNormalizeTrimsEachLineAndDropsEmptyOnes() {
        let text = ImageTextRecognizer.normalize(lines: ["  padded  ", "", "   ", "\ttabbed\n"])

        XCTAssertEqual(text, "padded\ntabbed")
    }

    func testNormalizeReturnsEmptyStringWhenNothingRecognized() {
        XCTAssertTrue(ImageTextRecognizer.normalize(lines: []).isEmpty)
        XCTAssertTrue(ImageTextRecognizer.normalize(lines: ["", "  "]).isEmpty)
    }
}
