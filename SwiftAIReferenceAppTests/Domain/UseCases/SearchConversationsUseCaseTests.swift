import XCTest
@testable import SwiftAIReferenceApp

final class SearchConversationsUseCaseTests: XCTestCase {
    func testEmptyQueryReturnsAllConversations() {
        let sut = DefaultSearchConversationsUseCase()
        let conversations = [
            Conversation(title: "One"),
            Conversation(title: "Two")
        ]

        XCTAssertEqual(sut.execute(conversations: conversations, query: ""), conversations)
        XCTAssertEqual(sut.execute(conversations: conversations, query: "   "), conversations)
    }

    func testMatchesTitlesAndMessagesIgnoringCaseAndDiacritics() {
        let sut = DefaultSearchConversationsUseCase()
        let titleMatch = Conversation(title: "Café plán", messages: [Message(role: .user, text: "Nič tu nie je")])
        let messageMatch = Conversation(title: "Research", messages: [Message(role: .assistant, text: "Příliš žluťoučký kůň úpěl ďábelské ódy.")])
        let nonMatch = Conversation(title: "Other", messages: [Message(role: .user, text: "Nothing relevant")])
        let conversations = [titleMatch, messageMatch, nonMatch]

        XCTAssertEqual(
            sut.execute(conversations: conversations, query: "cafe"),
            [titleMatch]
        )

        XCTAssertEqual(
            sut.execute(conversations: conversations, query: "PRILIS ZLUTOUCKY KUN"),
            [messageMatch]
        )
    }
}
