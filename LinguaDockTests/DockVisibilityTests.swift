import AppKit
import XCTest
@testable import LinguaDock

final class DockVisibilityTests: XCTestCase {
    func testVisibleWindowAlwaysKeepsTheDockIcon() {
        XCTAssertEqual(
            DockVisibility.policy(hidesDockWhenClosed: true, hasVisibleWindow: true),
            .regular
        )
        XCTAssertEqual(
            DockVisibility.policy(hidesDockWhenClosed: false, hasVisibleWindow: true),
            .regular
        )
    }

    func testNoWindowHidesTheDockIconOnlyWhenTheSettingIsOn() {
        XCTAssertEqual(
            DockVisibility.policy(hidesDockWhenClosed: true, hasVisibleWindow: false),
            .accessory
        )
        XCTAssertEqual(
            DockVisibility.policy(hidesDockWhenClosed: false, hasVisibleWindow: false),
            .regular
        )
    }
}
