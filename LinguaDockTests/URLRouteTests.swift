import XCTest
@testable import LinguaDock

final class URLRouteTests: XCTestCase {
    func testParsesPopClipURL() throws {
        let url = try XCTUnwrap(URL(string: "linguadock://translate?text=Hello%20world"))
        XCTAssertEqual(URLRoute(url: url), .translate("Hello world"))
    }

    func testRejectsEmptyText() throws {
        let url = try XCTUnwrap(URL(string: "linguadock://translate?text=%20%20"))
        XCTAssertNil(URLRoute(url: url))
    }
}
