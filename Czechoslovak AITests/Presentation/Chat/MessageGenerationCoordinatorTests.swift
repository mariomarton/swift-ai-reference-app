import Combine
import SwiftUI
import XCTest
@testable import Czechoslovak_AI

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

@MainActor
private final class BackgroundTaskManagerMock: BackgroundTaskManaging {
    private(set) var beginCalls: [UUID] = []
    private(set) var endCalls: [UUID] = []
    private var expirationHandlers: [UUID: @Sendable () -> Void] = [:]

    @discardableResult
    func beginTask(for conversationID: UUID, expirationHandler: @escaping @Sendable () -> Void) -> Bool {
        beginCalls.append(conversationID)
        expirationHandlers[conversationID] = expirationHandler
        return true
    }

    func endTask(for conversationID: UUID) {
        endCalls.append(conversationID)
        expirationHandlers.removeValue(forKey: conversationID)
    }

    func triggerExpiration(for conversationID: UUID) {
        expirationHandlers[conversationID]?()
    }
}

@MainActor
final class MessageGenerationCoordinatorTests: XCTestCase {
    private func awaitPublishedConversationState(
        for conversationID: UUID,
        in coordinator: MessageGenerationCoordinator,
        where predicate: @escaping (MessageGenerationCoordinator.ConversationState?) -> Bool
    ) async -> MessageGenerationCoordinator.ConversationState? {
        let initialState = coordinator.state(for: conversationID)
        if predicate(initialState) {
            return initialState
        }

        for await states in coordinator.statesPublisher.values {
            let state = states[conversationID]
            if predicate(state) {
                return state
            }
        }

        XCTFail("Publisher completed before expected published conversation state arrived")
        return coordinator.state(for: conversationID)
    }

    private func awaitConversationState(
        for conversationID: UUID,
        in coordinator: MessageGenerationCoordinator,
        where predicate: @escaping (MessageGenerationCoordinator.ConversationState?) -> Bool
    ) async -> MessageGenerationCoordinator.ConversationState? {
        let initialState = coordinator.state(for: conversationID)
        if predicate(initialState) {
            return initialState
        }

        for await states in coordinator.$states.values {
            let state = states[conversationID]
            if predicate(state) {
                return state
            }
        }

        XCTFail("Publisher completed before expected conversation state arrived")
        return coordinator.state(for: conversationID)
    }

    func testStartGenerationTransitionsThroughThinkingStreamingAndCompleted() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(sendMessageUseCase: useCase, updateInterval: .zero)
        }
        let conversationID = UUID()

        let didStart = sut.startGeneration(
            message: Message(role: .user, text: "Ahoj"),
            to: conversationID,
            model: nil
        )

        XCTAssertTrue(didStart)
        XCTAssertEqual(sut.state(for: conversationID)?.phase, .thinking)

        useCase.continuation?.yield("Reply")

        let streamingState = await awaitConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .streaming }
        )

        XCTAssertEqual(streamingState?.streamedText, "Reply")

        useCase.continuation?.finish()

        let completedState = await awaitConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .completed }
        )

        XCTAssertEqual(completedState?.streamedText, "")
        XCTAssertNotNil(completedState?.terminalEventID)
    }

    func testStatesPublisherEmitsStreamingAndCompletedUpdates() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(sendMessageUseCase: useCase, updateInterval: .zero)
        }
        let conversationID = UUID()

        let didStart = sut.startGeneration(
            message: Message(role: .user, text: "Ahoj"),
            to: conversationID,
            model: nil
        )

        XCTAssertTrue(didStart)

        useCase.continuation?.yield("Reply")

        let streamingState = await awaitPublishedConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .streaming && $0?.streamedText == "Reply" }
        )

        XCTAssertEqual(streamingState?.streamedText, "Reply")

        useCase.continuation?.finish()

        let completedState = await awaitPublishedConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .completed }
        )

        XCTAssertEqual(completedState?.phase, .completed)
        XCTAssertNotNil(completedState?.terminalEventID)
    }

    func testBackgroundSceneBeginsTaskForActiveGeneration() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let backgroundTaskManager = BackgroundTaskManagerMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(
                sendMessageUseCase: useCase,
                backgroundTaskManager: backgroundTaskManager,
                updateInterval: .zero
            )
        }
        let conversationID = UUID()

        let didStart = sut.startGeneration(
            message: Message(role: .user, text: "Ahoj"),
            to: conversationID,
            model: nil
        )

        XCTAssertTrue(didStart)

        sut.handleScenePhaseChange(.background)

        XCTAssertEqual(backgroundTaskManager.beginCalls, [conversationID])
    }

    func testTerminalStateEndsBackgroundTaskWhileBackgrounded() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let backgroundTaskManager = BackgroundTaskManagerMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(
                sendMessageUseCase: useCase,
                backgroundTaskManager: backgroundTaskManager,
                updateInterval: .zero
            )
        }
        let conversationID = UUID()

        let didStart = sut.startGeneration(
            message: Message(role: .user, text: "Ahoj"),
            to: conversationID,
            model: nil
        )
        XCTAssertTrue(didStart)

        sut.handleScenePhaseChange(.background)
        useCase.continuation?.finish()

        let completedState = await awaitConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .completed }
        )

        XCTAssertEqual(completedState?.phase, .completed)
        XCTAssertEqual(backgroundTaskManager.endCalls, [conversationID])
    }

    func testBackgroundTaskExpirationInterruptsGeneration() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let backgroundTaskManager = BackgroundTaskManagerMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(
                sendMessageUseCase: useCase,
                backgroundTaskManager: backgroundTaskManager,
                updateInterval: .zero
            )
        }
        let conversationID = UUID()

        let didStart = sut.startGeneration(
            message: Message(role: .user, text: "Ahoj"),
            to: conversationID,
            model: nil
        )
        XCTAssertTrue(didStart)

        sut.handleScenePhaseChange(.background)
        backgroundTaskManager.triggerExpiration(for: conversationID)

        let failedState = await awaitConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .failed }
        )

        XCTAssertEqual(failedState?.errorDescription, L10n.Chat.backgroundInterruptedMessage)
        XCTAssertEqual(backgroundTaskManager.endCalls, [conversationID])
    }

    func testStartGenerationRejectsDuplicateInFlightGeneration() async {
        let useCase = ControllableSendMessageUseCaseMock()
        let sut = await MainActor.run {
            MessageGenerationCoordinator(sendMessageUseCase: useCase, updateInterval: .zero)
        }
        let conversationID = UUID()

        let first = sut.startGeneration(
            message: Message(role: .user, text: "First"),
            to: conversationID,
            model: nil
        )
        let second = sut.startGeneration(
            message: Message(role: .user, text: "Second"),
            to: conversationID,
            model: nil
        )

        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(useCase.calls.count, 1)

        useCase.continuation?.finish()

        let completedState = await awaitConversationState(
            for: conversationID,
            in: sut,
            where: { $0?.phase == .completed }
        )

        XCTAssertEqual(completedState?.phase, .completed)
    }
}