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

private final class DeleteConversationUseCaseMock: DeleteConversationUseCase {
    var shouldThrow = false
    private(set) var deletedIDs: [UUID] = []

    func execute(id: UUID) async throws {
        if shouldThrow { throw NSError(domain: "mock", code: 3) }
        deletedIDs.append(id)
    }
}

@MainActor
private func makeViewModel(
    load: LoadConversationsUseCaseMock = .init(),
    create: CreateConversationUseCaseMock = .init(),
    delete: DeleteConversationUseCaseMock = .init()
) -> ConversationsListViewModel {
    ConversationsListViewModel(
        loadConversationsUseCase: load,
        createConversationUseCase: create,
        deleteConversationUseCase: delete
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
}
