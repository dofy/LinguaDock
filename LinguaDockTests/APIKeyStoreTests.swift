import XCTest
@testable import LinguaDock

final class APIKeyStoreTests: XCTestCase {
    func testProvidersUseDistinctKeychainAccounts() {
        let accounts = APIProvider.allCases.map(APIKeyStore.account(for:))

        XCTAssertEqual(Set(accounts).count, APIProvider.allCases.count)
    }
}
