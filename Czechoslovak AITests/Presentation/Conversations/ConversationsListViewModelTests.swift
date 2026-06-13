import Combine
import XCTest
@testable import Czechoslovak_AI

private final class LoadConversationsUseCaseMock: LoadConversationsUseCase {
    var result: Result<[Conversation], Error> = .success([])
    private(set) var executeCallCount = 0

    func execute() async throws -> [Conversation] {
        executeCallCount += 1
        return try result.get()
    }
}

private final class CreateConversationUseCaseMock: CreateConversationUseCase {
    var result: Result<Conversation, Error> = .success(Conversation(title: "Untitled"))
    private(set) var receivedTitle: String?

    func execute(title: String?) async throws -> Conversation {
        receivedTitle = title
        return try result.get()
    }
}

private final class LoadRecentMessagesUseCaseMock: LoadRecentMessagesUseCase {
    var messagesByConversationID: [UUID: [Message]] = [:]
    private(set) var calls: [(UUID, Int?)] = []

    func loadRecentMessages(for conversationID: UUID, limit: Int?) async throws -> [Message] {
        calls.append((conversationID, limit))
        return messagesByConversationID[conversationID] ?? []
    }
}

private final class DeleteConversationUseCaseMock: DeleteConversationUseCase {
    var shouldThrow = false
    private(set) var deletedIDs: [UUID] = []

    func execute(id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "mock", code: 3) }
        deletedIDs.append(id)
    }
}

private final class MessageGenerationCoordinatorMock: ConversationGenerationStateObserving {
    @Published
    private var states: [UUID: MessageGenerationCoordinator.ConversationState] = [:]

    var statesPublisher: AnyPublisher<[UUID: MessageGenerationCoordinator.ConversationState], Never> {
        $states.eraseToAnyPublisher()
    }

    func publishState(_ state: MessageGenerationCoordinator.ConversationState?, for conversationID: UUID) {
        var updatedStates = states
        if let state {
            updatedStates[conversationID] = state
        } else {
            updatedStates.removeValue(forKey: conversationID)
        }
        states = updatedStates
    }
}

private var retainedViewModels: [AnyObject] = []

private func retainForTest(_ object: AnyObject) {
    retainedViewModels.append(object)
}

@MainActor
private func awaitGeneratingConversationIDs(
    _ expected: Set<UUID>,
    in sut: ConversationsListViewModel,
    timeoutNanoseconds: UInt64 = 500_000_000
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .nanoseconds(Int64(timeoutNanoseconds)))

    while clock.now < deadline {
        if sut.generatingConversationIDs == expected {
            return
        }

        await Task.yield()
    }

    XCTFail("Timed out waiting for generatingConversationIDs to become \(expected)")
}

@MainActor
private func makeViewModel(
    load: LoadConversationsUseCaseMock = .init(),
    loadRecentMessages: LoadRecentMessagesUseCaseMock = .init(),
    search: SearchConversationsUseCase? = nil,
    create: CreateConversationUseCaseMock = .init(),
    delete: DeleteConversationUseCaseMock = .init(),
    coordinator: MessageGenerationCoordinatorMock? = nil
) -> ConversationsListViewModel {
    ConversationsListViewModel(
        loadConversationsUseCase: load,
        loadRecentMessagesUseCase: loadRecentMessages,
        searchConversationsUseCase: search ?? DefaultSearchConversationsUseCase(),
        createConversationUseCase: create,
        deleteConversationUseCase: delete,
        generationCoordinator: coordinator
    )
}

@MainActor
final class ConversationsListViewModelTests: XCTestCase {
    func testLoadConversationsSuccessPopulatesState() async {
        let loadMock = LoadConversationsUseCaseMock()
        let expected = [Conversation(title: "A"), Conversation(title: "B")]
        loadMock.result = .success(expected)

        let sut = makeViewModel(load: loadMock)

        await sut.loadConversations()

        XCTAssertEqual(loadMock.executeCallCount, 1)
        XCTAssertEqual(sut.conversations, expected)
        XCTAssertNil(sut.alert)
        XCTAssertFalse(sut.isLoading)
    }

    func testSearchTextFiltersDisplayedConversations() async {
        let loadMock = LoadConversationsUseCaseMock()
        let messagesMock = LoadRecentMessagesUseCaseMock()
        let matching = Conversation(title: "Travel")
        let other = Conversation(title: "Work", messages: [Message(role: .user, text: "Quarterly planning")])
        messagesMock.messagesByConversationID[matching.id] = [Message(role: .user, text: "Paris itinerary")]
        messagesMock.messagesByConversationID[other.id] = [Message(role: .user, text: "Quarterly planning")]
        loadMock.result = .success([matching, other])

        let sut = makeViewModel(load: loadMock, loadRecentMessages: messagesMock)

        await sut.loadConversations()
        sut.searchText = "paris"

        XCTAssertEqual(sut.displayedConversations, [matching])
        XCTAssertTrue(sut.hasActiveSearch)
    }

    func testLoadConversationsFailureSetsAlert() async {
        let loadMock = LoadConversationsUseCaseMock()
        loadMock.result = .failure(NSError(domain: "test", code: 1))

        let sut = makeViewModel(load: loadMock)

        await sut.loadConversations()

        XCTAssertEqual(loadMock.executeCallCount, 1)
        XCTAssertTrue(sut.conversations.isEmpty)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, true)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadConversationsAgainReflectsUpdatedPersistedTitle() async {
        let loadMock = LoadConversationsUseCaseMock()
        let conversationID = UUID()
        loadMock.result = .success([
            Conversation(id: conversationID, title: nil)
        ])

        let sut = makeViewModel(load: loadMock)

        await sut.loadConversations()
        XCTAssertEqual(sut.conversations.first?.title, nil)

        loadMock.result = .success([
            Conversation(id: conversationID, title: "Vygenerovaný názov")
        ])

        await sut.loadConversations()

        XCTAssertEqual(loadMock.executeCallCount, 2)
        XCTAssertEqual(sut.conversations.first?.title, "Vygenerovaný názov")
    }

    func testCreateConversationSuccessSelectsCreatedConversation() async {
        let createMock = CreateConversationUseCaseMock()
        let created = Conversation(title: "New chat")
        createMock.result = .success(created)

        let sut = makeViewModel(create: createMock)

        await sut.createConversation(title: "New chat")

        XCTAssertEqual(createMock.receivedTitle, "New chat")
        XCTAssertEqual(sut.conversations.first?.id, created.id)
        XCTAssertEqual(sut.selectedConversationID, created.id)
        XCTAssertNil(sut.alert)
    }

    func testCreateConversationFailureSetsAlert() async {
        let createMock = CreateConversationUseCaseMock()
        createMock.result = .failure(NSError(domain: "test", code: 2))

        let sut = makeViewModel(create: createMock)

        await sut.createConversation(title: "Will fail")

        XCTAssertTrue(sut.conversations.isEmpty)
        XCTAssertNil(sut.selectedConversationID)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, false)
    }

    // MARK: - Delete

    func testDeleteConversationRemovesItFromListOptimistically() async {
        let loadMock = LoadConversationsUseCaseMock()
        let deleteMock = DeleteConversationUseCaseMock()
        let conv = Conversation(title: "Bye")
        loadMock.result = .success([conv])

        let sut = makeViewModel(load: loadMock, delete: deleteMock)
        await sut.loadConversations()

        await sut.deleteConversation(id: conv.id)

        XCTAssertTrue(sut.conversations.isEmpty)
        XCTAssertEqual(deleteMock.deletedIDs, [conv.id])
        XCTAssertNil(sut.alert)
    }

    func testDeleteSelectedConversationClearsSelection() async {
        let loadMock = LoadConversationsUseCaseMock()
        let deleteMock = DeleteConversationUseCaseMock()
        let conv = Conversation(title: "Selected")
        loadMock.result = .success([conv])

        let sut = makeViewModel(load: loadMock, delete: deleteMock)
        await sut.loadConversations()
        sut.selectedConversationID = conv.id

        await sut.deleteConversation(id: conv.id)

        XCTAssertNil(sut.selectedConversationID)
    }

    func testDeleteConversationFailureRollsBackAndShowsAlert() async {
        let loadMock = LoadConversationsUseCaseMock()
        let deleteMock = DeleteConversationUseCaseMock()
        deleteMock.shouldThrow = true
        let conv = Conversation(title: "Will fail delete")
        loadMock.result = .success([conv])

        let sut = makeViewModel(load: loadMock, delete: deleteMock)
        await sut.loadConversations()

        await sut.deleteConversation(id: conv.id)

        // List should be restored
        XCTAssertEqual(sut.conversations, [conv])
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.isRetryable, false)
    }

    func testGeneratingConversationIDsReflectCoordinatorInProgressStates() async {
        let coordinator = MessageGenerationCoordinatorMock()
        let generatingID = UUID()
        let idleID = UUID()

        let sut = makeViewModel(coordinator: coordinator)

        await Task.yield()

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .thinking,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: generatingID
        )
        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .completed,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: UUID()
            ),
            for: idleID
        )

        await awaitGeneratingConversationIDs([generatingID], in: sut)

        XCTAssertEqual(sut.generatingConversationIDs, [generatingID])
        XCTAssertTrue(sut.isGenerating(conversationID: generatingID))
        XCTAssertFalse(sut.isGenerating(conversationID: idleID))

        sut.stopGenerationObservation()
        retainForTest(sut)
    }

    func testGeneratingConversationIDsClearOnTerminalAndRemovedStates() async {
        let coordinator = MessageGenerationCoordinatorMock()
        let conversationID = UUID()

        let sut = makeViewModel(coordinator: coordinator)

        await Task.yield()

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .streaming,
                streamedText: "Ahoj",
                errorDescription: nil,
                terminalEventID: nil
            ),
            for: conversationID
        )

        await awaitGeneratingConversationIDs([conversationID], in: sut)

        coordinator.publishState(
            MessageGenerationCoordinator.ConversationState(
                phase: .failed,
                streamedText: "Ahoj",
                errorDescription: "Interrupted",
                terminalEventID: UUID()
            ),
            for: conversationID
        )

        await awaitGeneratingConversationIDs([], in: sut)

        coordinator.publishState(nil, for: conversationID)

        await awaitGeneratingConversationIDs([], in: sut)
        XCTAssertFalse(sut.isGenerating(conversationID: conversationID))

        sut.stopGenerationObservation()
        retainForTest(sut)
    }
}
