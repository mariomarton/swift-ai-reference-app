import XCTest
@testable import Czechoslovak_AI

final class ConversationAndErrorTests: XCTestCase {
    func testConversationAppendUpdatesUpdatedAtAndLastMessage() {
        var conv = Conversation(title: "Test")
        let before = conv.updatedAt
        let msg = ChatMessage(role: .user, text: "Hello")
        sleep(1) // ensure timestamp difference
        conv.append(msg)

        XCTAssertEqual(conv.lastMessage, msg)
        XCTAssertTrue(conv.updatedAt > before)
        XCTAssertEqual(conv.messages.count, 1)
    }

    func testDomainErrorDescriptions() {
        let repoWrapped = DomainError.repositoryError(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "fail"]))
        XCTAssertTrue(repoWrapped.errorDescription?.contains("fail") ?? false)

        let engineWrapped = DomainError.engineError(NSError(domain: "x", code: 2, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        XCTAssertTrue(engineWrapped.errorDescription?.contains("boom") ?? false)

        XCTAssertEqual(DomainError.invalidModel.errorDescription, "Invalid or unsupported model")
    }
}
