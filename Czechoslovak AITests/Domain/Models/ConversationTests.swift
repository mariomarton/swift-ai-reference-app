import XCTest
@testable import Czechoslovak_AI

final class ConversationTests: XCTestCase {
    func testConversationAppendUpdatesUpdatedAtAndLastMessage() {
        var conv = Conversation(title: "Test")
        let before = conv.updatedAt
        let msg = Message(role: .user, text: "Hello")
        sleep(1) // ensure timestamp difference
        conv.append(msg)

        XCTAssertEqual(conv.lastMessage, msg)
        XCTAssertTrue(conv.updatedAt > before)
        XCTAssertEqual(conv.messages.count, 1)
    }
}
