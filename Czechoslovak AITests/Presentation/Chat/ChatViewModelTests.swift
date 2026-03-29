import XCTest
@testable import Czechoslovak_AI

private final class LoadRecentMessagesUseCaseMock: LoadRecentMessagesUseCase {
    var onLoad: ((UUID, Int?) throws -> [Message])?
    private(set) var calls: [(UUID, Int?)] = []

    func loadRecentMessages(for conversationID: UUID, limit: Int?) async throws -> [Message] {
        calls.append((conversationID, limit))
        if let onLoad {
            return try onLoad(conversationID, limit)
        }
        return []
    }
}

private final class SendMessageUseCaseMock: SendMessageUseCase {
    var tokensToYield: [String] = ["ok"]
    var shouldThrow = false
    private(set) var calls: [(Message, UUID, LLMModel?)] = []

    func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        calls.append((message, conversationID, model))
        let tokens = tokensToYield
        let shouldThrow = self.shouldThrow
        return AsyncThrowingStream { continuation in
            if shouldThrow {
                continuation.finish(throwing: NSError(domain: "mock", code: 2))
            } else {
                for token in tokens { continuation.yield(token) }
                continuation.finish()
            }
        }
    }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    func testLoadMessagesSuccessUpdatesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()
        let expected = [
            Message(role: .user, text: "Hello"),
            Message(role: .assistant, text: "Hi")
        ]
        loadMock.onLoad = { _, _ in expected }

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )

        await sut.loadMessages(limit: 50)

        XCTAssertEqual(loadMock.calls.count, 1)
        XCTAssertEqual(loadMock.calls.first?.0, conversationID)
        XCTAssertEqual(loadMock.calls.first?.1, 50)
        XCTAssertEqual(sut.messages, expected)
        XCTAssertNil(sut.alert)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadMessagesFailureSetsAlert() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()
        loadMock.onLoad = { _, _ in throw NSError(domain: "test", code: 1) }

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )

        await sut.loadMessages()

        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, true)
        XCTAssertFalse(sut.isLoading)
    }

    func testSendMessageSuccessClearsDraftAndRefreshesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()
        sendMock.tokensToYield = ["Reply"]
        let expectedMessages = [
            Message(role: .user, text: "Ahoj"),
            Message(role: .assistant, text: "Reply")
        ]
        loadMock.onLoad = { _, _ in expectedMessages }

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )
        sut.draftText = "Ahoj"

        await sut.sendMessage()

        XCTAssertEqual(sendMock.calls.count, 1)
        XCTAssertEqual(sendMock.calls.first?.0.text, "Ahoj")
        XCTAssertEqual(sendMock.calls.first?.1, conversationID)
        XCTAssertEqual(sut.draftText, "")
        XCTAssertEqual(sut.messages, expectedMessages)
        XCTAssertNil(sut.streamingText)
        XCTAssertNil(sut.alert)
        XCTAssertFalse(sut.isSending)
    }

    func testSendMessageFailureShowsAlertAndStillRefreshesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()
        sendMock.shouldThrow = true

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )
        sut.draftText = "Will fail"

        await sut.sendMessage()

        XCTAssertEqual(sendMock.calls.count, 1)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, false)
        XCTAssertFalse(sut.isSending)
        XCTAssertNil(sut.streamingText)
        // Messages should still be refreshed even after a send failure
        XCTAssertEqual(loadMock.calls.count, 1)
    }

    func testStreamingTextIsNilAfterSuccessfulSend() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()
        sendMock.tokensToYield = ["Hello", " ", "World"]

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )
        sut.draftText = "Test"

        await sut.sendMessage()

        XCTAssertNil(sut.streamingText)
        XCTAssertFalse(sut.isSending)
    }

    func testSendMessageIgnoresBlankDraft() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = SendMessageUseCaseMock()

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            sendMessageUseCase: sendMock
        )
        sut.draftText = "   \n "

        await sut.sendMessage()

        XCTAssertEqual(sendMock.calls.count, 0)
        XCTAssertEqual(loadMock.calls.count, 0)
        XCTAssertFalse(sut.isSending)
    }
}
