import XCTest
import Security
@testable import LinguaDock

final class KeychainServiceMigrationTests: XCTestCase {
    func testRenamesAllAccountsWithoutReadingValues() throws {
        var renamed: [String] = []
        try KeychainServiceMigration.run(accounts: ["first", "second"]) { account in
            renamed.append(account)
            return errSecSuccess
        }
        XCTAssertEqual(renamed, ["first", "second"])
    }

    func testCollisionOrLockedKeychainStopsWithoutDeletingRemainingAccounts() {
        for error in [errSecDuplicateItem, errSecInteractionNotAllowed] {
            var attempted: [String] = []
            XCTAssertThrowsError(try KeychainServiceMigration.run(accounts: ["first", "second"]) { account in
                attempted.append(account)
                return error
            })
            XCTAssertEqual(attempted, ["first"])
        }
    }
}
