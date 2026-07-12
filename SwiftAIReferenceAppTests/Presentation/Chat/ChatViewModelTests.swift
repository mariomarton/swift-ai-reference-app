import Combine
import SwiftUI
import XCTest
@testable import SwiftAIReferenceApp

private final class ControllableSendMessageUseCaseMock: SendMessageUseCase {
    private(set) var calls: [(Message, UUID, LLMModel?)] = []
    var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        calls.append((message, conversationID, model))

        return AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }
}

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

private final class MessageGenerationCoordinatorMock: MessageGenerationCoordinating {
    typealias ConversationState = MessageGenerationCoordinator.ConversationState

    private let statesSubject = CurrentValueSubject<[UUID: ConversationState], Never>([:])

    private(set) var startCalls: [(Message, UUID, LLMModel?)] = []
    private(set) var stopAndStartCalls: [(Message, UUID, LLMModel?, String)] = []
    private(set) var interruptedConversations: [(UUID, String)] = []
    private(set) var interruptCalls: [(UUID, String)] = []
    private(set) var clearCalls: [(UUID, UUID?)] = []
    var startGenerationResult: MessageGenerationStartResult = .started

    var statesPublisher: AnyPublisher<[UUID: ConversationState], Never> {
        statesSubject.eraseToAnyPublisher()
    }

    func state(for conversationID: UUID) -> ConversationState? {
        statesSubject.value[conversationID]
    }

    @discardableResult
    func startGeneration(message: Message, to conversationID: UUID, model: LLMModel?) -> MessageGenerationStartResult {
        startCalls.append((message, conversationID, model))

        guard startGenerationResult == .started else {
            return startGenerationResult
        }

        publishState(
            ConversationState(
                phase: .thinking,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: conversationID
        )

        return .started
    }

    @discardableResult
    func stopActiveGenerationAndStart(
        message: Message,
        to conversationID: UUID,
        model: LLMModel?,
        interruptionErrorDescription: String
    ) -> MessageGenerationStartResult {
        stopAndStartCalls.append((message, conversationID, model, interruptionErrorDescription))

        if case .blocked(let activeConversationID) = startGenerationResult,
           activeConversationID != conversationID {
            interruptedConversations.append((activeConversationID, interruptionErrorDescription))
            publishState(
                ConversationState(
                    phase: .failed,
                    streamedText: "",
                    errorDescription: interruptionErrorDescription,
                    terminalEventID: UUID()
                ),
                for: activeConversationID
            )
            startGenerationResult = .started
        }

        return startGeneration(message: message, to: conversationID, model: model)
    }

    func interruptGeneration(for conversationID: UUID, errorDescription: String) {
        interruptCalls.append((conversationID, errorDescription))
        publishState(
            ConversationState(
                phase: .failed,
                streamedText: statesSubject.value[conversationID]?.streamedText ?? "",
                errorDescription: errorDescription,
                terminalEventID: UUID()
            ),
            for: conversationID
        )
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {}

    func clearTerminalState(for conversationID: UUID, matching terminalEventID: UUID?) {
        clearCalls.append((conversationID, terminalEventID))

        var updatedStates = statesSubject.value
        if let state = updatedStates[conversationID], !state.isInProgress {
            if let terminalEventID, state.terminalEventID != terminalEventID {
                return
            }
            updatedStates.removeValue(forKey: conversationID)
            statesSubject.send(updatedStates)
        }
    }

    func publishState(_ state: ConversationState?, for conversationID: UUID) {
        var updatedStates = statesSubject.value
        updatedStates[conversationID] = state
        if state == nil {
            updatedStates.removeValue(forKey: conversationID)
        }
        statesSubject.send(updatedStates)
    }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    private func makeSUT(
        conversationID: UUID,
        loadMock: LoadRecentMessagesUseCaseMock,
        coordinator: MessageGenerationCoordinatorMock = MessageGenerationCoordinatorMock()
    ) -> ChatViewModel {
        ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            generationCoordinator: coordinator
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition", file: file, line: line)
    }

    func testLoadMessagesSuccessUpdatesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        let expected = [
            Message(role: .user, text: "Hello"),
            Message(role: .assistant, text: "Hi")
        ]
        loadMock.onLoad = { _, _ in expected }

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)

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
        let coordinator = MessageGenerationCoordinatorMock()
        loadMock.onLoad = { _, _ in throw NSError(domain: "test", code: 1) }

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)

        await sut.loadMessages()

        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, true)
        XCTAssertFalse(sut.isLoading)
    }

    func testSendMessageSuccessClearsDraftAndRefreshesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        let terminalEventID = UUID()
        let expectedMessages = [
            Message(role: .user, text: "Ahoj"),
            Message(role: .assistant, text: "Reply")
        ]
        loadMock.onLoad = { _, _ in expectedMessages }

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Ahoj"

        await sut.sendMessage()

        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.role, .user)
        XCTAssertEqual(sut.messages.first?.text, "Ahoj")
        XCTAssertEqual(sut.draftText, "")
        XCTAssertEqual(coordinator.startCalls.count, 1)
        XCTAssertEqual(coordinator.startCalls.first?.0.text, "Ahoj")
        XCTAssertEqual(coordinator.startCalls.first?.1, conversationID)
        XCTAssertTrue(sut.isSending)
        XCTAssertNil(sut.streamingText)

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .completed,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: terminalEventID
            ),
            for: conversationID
        )

        await waitUntil { loadMock.calls.count == 1 }
        await waitUntil { sut.messages == expectedMessages }
        await waitUntil { coordinator.clearCalls.count == 1 }

        XCTAssertEqual(sut.messages, expectedMessages)
        XCTAssertNil(sut.streamingText)
        XCTAssertNil(sut.alert)
        XCTAssertFalse(sut.isSending)
        XCTAssertEqual(coordinator.clearCalls.first?.0, conversationID)
        XCTAssertEqual(coordinator.clearCalls.first?.1, terminalEventID)
    }

    func testSendMessageFailureShowsAlertAndStillRefreshesMessages() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        let terminalEventID = UUID()

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Will fail"

        await sut.sendMessage()

        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.text, "Will fail")
        XCTAssertTrue(sut.isSending)

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .failed,
                streamedText: "",
                errorDescription: "The operation couldn’t be completed. (mock error 2.)",
                terminalEventID: terminalEventID
            ),
            for: conversationID
        )

        await waitUntil { sut.alert != nil }
        await waitUntil { loadMock.calls.count == 1 }
        await waitUntil { coordinator.clearCalls.count == 1 }

        XCTAssertEqual(coordinator.startCalls.count, 1)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, false)
        XCTAssertEqual(sut.messages, [])
        XCTAssertFalse(sut.isSending)
        XCTAssertNil(sut.streamingText)
        XCTAssertEqual(loadMock.calls.count, 1)
        XCTAssertEqual(coordinator.clearCalls.first?.0, conversationID)
        XCTAssertEqual(coordinator.clearCalls.first?.1, terminalEventID)
    }

    func testStreamingTextIsNilAfterSuccessfulSend() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        let terminalEventID = UUID()

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Test"

        await sut.sendMessage()
        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .streaming,
                streamedText: "Hello World",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: conversationID
        )

        XCTAssertEqual(sut.streamingText, "Hello World")
        XCTAssertTrue(sut.isSending)

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .completed,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: terminalEventID
            ),
            for: conversationID
        )

        await waitUntil { loadMock.calls.count == 1 }
        await waitUntil { !sut.isSending }

        XCTAssertNil(sut.streamingText)
        XCTAssertFalse(sut.isSending)
    }

    func testSendMessageIgnoresBlankDraft() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "   \n "

        await sut.sendMessage()

        XCTAssertEqual(coordinator.startCalls.count, 0)
        XCTAssertEqual(loadMock.calls.count, 0)
        XCTAssertFalse(sut.isSending)
    }

    func testSendMessageWhenBlockedShowsGenerationConflictPrompt() async {
        let conversationID = UUID()
        let foreignConversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        coordinator.startGenerationResult = .blocked(activeConversationID: foreignConversationID)

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Ahoj"

        await sut.sendMessage()

        XCTAssertEqual(sut.messages.count, 0)
        XCTAssertEqual(sut.draftText, "Ahoj")
        XCTAssertEqual(sut.generationConflictPrompt?.activeConversationID, foreignConversationID)
        XCTAssertFalse(sut.isSending)
    }

    func testStopCurrentAndSendHereStartsPendingMessage() async {
        let conversationID = UUID()
        let foreignConversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        coordinator.startGenerationResult = .blocked(activeConversationID: foreignConversationID)

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Ahoj"

        await sut.sendMessage()

        XCTAssertNotNil(sut.generationConflictPrompt)

        sut.stopCurrentAndSendHere()

        XCTAssertNil(sut.generationConflictPrompt)
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.text, "Ahoj")
        XCTAssertEqual(sut.draftText, "")
        XCTAssertTrue(sut.isSending)
        XCTAssertEqual(coordinator.stopAndStartCalls.count, 1)
        XCTAssertEqual(coordinator.stopAndStartCalls.first?.1, conversationID)
        XCTAssertEqual(coordinator.interruptedConversations.count, 1)
        XCTAssertEqual(coordinator.interruptedConversations.first?.0, foreignConversationID)
    }

    func testStopGenerationInterruptsCurrentConversationWithoutAlert() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Ahoj"

        await sut.sendMessage()
        XCTAssertTrue(sut.isSending)

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .streaming,
                streamedText: "Partial",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: conversationID
        )

        sut.stopGeneration()

        await waitUntil { !sut.isSending }
        await waitUntil { coordinator.clearCalls.count == 1 }

        XCTAssertEqual(coordinator.interruptCalls.count, 1)
        XCTAssertEqual(coordinator.interruptCalls.first?.0, conversationID)
        XCTAssertEqual(coordinator.interruptCalls.first?.1, L10n.Chat.userStoppedGenerationMessage)
        XCTAssertNil(sut.alert)
    }

    func testSendMessageWorksImmediatelyAfterStopGeneration() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()

        let sut = makeSUT(conversationID: conversationID, loadMock: loadMock, coordinator: coordinator)
        sut.draftText = "Prvá"

        await sut.sendMessage()
        XCTAssertTrue(sut.isSending)

        sut.stopGeneration()
        await waitUntil { !sut.isSending }

        sut.draftText = "Druhá"
        await sut.sendMessage()

        XCTAssertEqual(coordinator.startCalls.count, 2)
        XCTAssertEqual(sut.messages.last?.text, "Druhá")
        XCTAssertTrue(sut.isSending)
    }

    func testViewModelRestoresInProgressStreamingStateFromCoordinator() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let coordinator = MessageGenerationCoordinatorMock()
        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .streaming,
                streamedText: "Ahoj svet",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: conversationID
        )

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            generationCoordinator: coordinator
        )

        XCTAssertTrue(sut.isSending)
        XCTAssertEqual(sut.streamingText, "Ahoj svet")
    }

    func testViewModelUpdatesFromRealCoordinatorWhileChatRemainsOpen() async {
        let conversationID = UUID()
        let loadMock = LoadRecentMessagesUseCaseMock()
        let sendMock = ControllableSendMessageUseCaseMock()
        let expectedMessages = [
            Message(role: .user, text: "Ahoj"),
            Message(role: .assistant, text: "Reply")
        ]
        loadMock.onLoad = { _, _ in expectedMessages }

        let coordinator = await MainActor.run {
            MessageGenerationCoordinator(
                sendMessageUseCase: sendMock,
                updateInterval: .zero
            )
        }

        let sut = ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadMock,
            generationCoordinator: coordinator
        )
        sut.draftText = "Ahoj"

        await sut.sendMessage()

        XCTAssertTrue(sut.isSending)
        XCTAssertNil(sut.streamingText)
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.text, "Ahoj")

        sendMock.continuation?.yield("Reply")

        await waitUntil {
            sut.streamingText == "Reply"
        }

        XCTAssertEqual(sut.streamingText, "Reply")
        XCTAssertTrue(sut.isSending)

        sendMock.continuation?.finish()

        await waitUntil {
            sut.messages == expectedMessages
        }
        await waitUntil {
            !sut.isSending
        }

        XCTAssertEqual(sut.messages, expectedMessages)
        XCTAssertNil(sut.streamingText)
        XCTAssertFalse(sut.isSending)
        XCTAssertNil(sut.alert)
    }
}
