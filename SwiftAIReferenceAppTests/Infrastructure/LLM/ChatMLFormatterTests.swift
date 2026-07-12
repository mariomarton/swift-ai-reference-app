import XCTest
@testable import SwiftAIReferenceApp

final class ChatMLFormatterTests: XCTestCase {

    // MARK: - Default system prompt injection

    func testInjectsDefaultSystemPromptWhenHistoryHasNoSystemTurn() {
        let messages = [Message(role: .user, text: "Ahoj")]
        let prompt = ChatMLFormatter.format(messages)
        XCTAssertTrue(prompt.hasPrefix("<|im_start|>system\n"),
                      "Prompt should begin with the default system turn")
        XCTAssertTrue(prompt.contains(ChatMLFormatter.defaultSystemPrompt))
    }

    func testDoesNotDuplicateSystemPromptWhenHistoryAlreadyHasOne() {
        let messages = [
            Message(role: .system, text: "Custom system"),
            Message(role: .user,   text: "Hi")
        ]
        let prompt = ChatMLFormatter.format(messages)
        let occurrences = prompt.components(separatedBy: "<|im_start|>system").count - 1
        XCTAssertEqual(occurrences, 1, "Should contain exactly one system turn")
        XCTAssertTrue(prompt.contains("Custom system"))
        XCTAssertFalse(prompt.contains(ChatMLFormatter.defaultSystemPrompt))
    }

    // MARK: - Role names

    func testUserTurnFormattedCorrectly() {
        let messages = [Message(role: .user, text: "Hello")]
        let prompt = ChatMLFormatter.format(messages)
        XCTAssertTrue(prompt.contains("<|im_start|>user\nHello<|im_end|>"))
    }

    func testAssistantTurnFormattedCorrectly() {
        let messages = [
            Message(role: .user,      text: "Hello"),
            Message(role: .assistant, text: "Hi!")
        ]
        let prompt = ChatMLFormatter.format(messages)
        XCTAssertTrue(prompt.contains("<|im_start|>assistant\nHi!<|im_end|>"))
    }

    // MARK: - Trailing assistant opener

    func testPromptEndsWithOpenAssistantTurn() {
        let messages = [Message(role: .user, text: "Test")]
        let prompt = ChatMLFormatter.format(messages)
        XCTAssertTrue(prompt.hasSuffix("<|im_start|>assistant\n"),
                      "Prompt must end with the open assistant turn so the model continues from there")
    }

    // MARK: - Multi-turn ordering

    func testMultiTurnOrderIsPreserved() {
        let messages: [Message] = [
            Message(role: .user,      text: "Turn 1"),
            Message(role: .assistant, text: "Reply 1"),
            Message(role: .user,      text: "Turn 2"),
        ]
        let prompt = ChatMLFormatter.format(messages)

        let t1 = prompt.range(of: "Turn 1")!
        let r1 = prompt.range(of: "Reply 1")!
        let t2 = prompt.range(of: "Turn 2")!

        XCTAssertLessThan(t1.lowerBound, r1.lowerBound)
        XCTAssertLessThan(r1.lowerBound, t2.lowerBound)
    }

    // MARK: - Token boundary correctness

    func testEachTurnContainsImStartAndImEnd() {
        let messages = [
            Message(role: .user,      text: "Q"),
            Message(role: .assistant, text: "A"),
        ]
        let prompt = ChatMLFormatter.format(messages)
        // Every closed turn must have a matching <|im_end|>
        let starts = prompt.components(separatedBy: "<|im_start|>").count - 1
        let ends   = prompt.components(separatedBy: "<|im_end|>").count - 1
        // starts = system + user + assistant (closed) + 1 open assistant = 4
        // ends   = system + user + assistant (closed)                    = 3
        XCTAssertEqual(ends, starts - 1,
                       "Every turn except the trailing open assistant turn should be closed with <|im_end|>")
    }
}
