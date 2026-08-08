import XCTest
@testable import SwiftAIReferenceApp

final class DomainErrorTests: XCTestCase {
    func testRepositoryErrorContainsWrappedDescription() {
        let wrapped = DomainError.repositoryError(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "fail"]))
        XCTAssertTrue(wrapped.errorDescription?.contains("fail") ?? false)
    }

    func testEngineErrorContainsWrappedDescription() {
        let wrapped = DomainError.engineError(NSError(domain: "x", code: 2, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        XCTAssertTrue(wrapped.errorDescription?.contains("boom") ?? false)
    }

    func testInvalidModelErrorDescription() {
        XCTAssertEqual(DomainError.invalidModel.errorDescription, L10n.Errors.invalidModel)
    }

    func testInvalidConversationTitleErrorDescription() {
        XCTAssertEqual(
            DomainError.invalidConversationTitle.errorDescription,
            L10n.Errors.invalidConversationTitle
        )
    }

    func testConversationNotFoundErrorDescription() {
        XCTAssertEqual(
            DomainError.conversationNotFound.errorDescription,
            L10n.Errors.conversationNotFound
        )
    }

    func testUnknownErrorDescription() {
        XCTAssertEqual(DomainError.unknown.errorDescription, L10n.Errors.unknown)
    }
}
