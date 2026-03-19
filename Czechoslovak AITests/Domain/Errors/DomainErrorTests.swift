import XCTest
@testable import Czechoslovak_AI

final class DomainErrorTests: XCTestCase {
    func testDomainErrorDescriptions() {
        let repoWrapped = DomainError.repositoryError(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "fail"]))
        XCTAssertTrue(repoWrapped.errorDescription?.contains("fail") ?? false)

        let engineWrapped = DomainError.engineError(NSError(domain: "x", code: 2, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        XCTAssertTrue(engineWrapped.errorDescription?.contains("boom") ?? false)

        XCTAssertEqual(DomainError.invalidModel.errorDescription, "Invalid or unsupported model")
    }
}
