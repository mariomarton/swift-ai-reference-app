import XCTest
@testable import Czechoslovak_AI

final class MockConversationRepository: ConversationRepository {
    var conversations: [Conversation] = []
    var shouldThrowOnCreate = false
    var shouldThrowOnDelete = false

    func loadConversation(id: UUID) async throws -> Conversation? {
        conversations.first { $0.id == id }
    }

    func updateConversation(_ conversation: Conversation) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw NSError(domain: "mock", code: 2)
        }
        conversations[index] = conversation
    }

    func createConversation(title: String?) async throws -> Conversation {
        if shouldThrowOnCreate { throw NSError(domain: "mock", code: 1) }
        let conv = Conversation(title: title)
        conversations.append(conv)
        return conv
    }

    func listConversations() async throws -> [Conversation] {
        return conversations
    }

    func deleteConversation(id: UUID) async throws {
        if shouldThrowOnDelete { throw NSError(domain: "mock", code: 3) }
        conversations.removeAll { $0.id == id }
    }
}

@MainActor
final class ConversationUseCasesTests: XCTestCase {
    func testCreateConversationHappyPath() async throws {
        let repo = MockConversationRepository()
        let useCase = DefaultCreateConversationUseCase(repository: repo)

        let created = try await useCase.execute(title: "Test")
        XCTAssertEqual(created.title, "Test")
        XCTAssertEqual(repo.conversations.count, 1)
    }

    func testLoadConversationsReturnsList() async throws {
        let repo = MockConversationRepository()
        repo.conversations = [Conversation(title: "A"), Conversation(title: "B")]
        let useCase = DefaultLoadConversationsUseCase(repository: repo)

        let loaded = try await useCase.execute()
        XCTAssertEqual(loaded.count, 2)
    }

    func testCreateThrowsPropagates() async throws {
        let repo = MockConversationRepository()
        repo.shouldThrowOnCreate = true
        let useCase = DefaultCreateConversationUseCase(repository: repo)

        do {
            _ = try await useCase.execute(title: "x")
            XCTFail("Expected throw")
        } catch {
        }
            // expected
    }

    // MARK: - Delete

    func testDeleteConversationRemovesItFromRepository() async throws {
        let conversationRepo = MockConversationRepository()
        let messageRepo = RepoMockForLoad()
        let toDelete = Conversation(title: "To delete")
        conversationRepo.conversations = [toDelete, Conversation(title: "Keep")]

        let useCase = DefaultDeleteConversationUseCase(
            conversationRepository: conversationRepo,
            messageRepository: messageRepo
        )

        try await useCase.execute(id: toDelete.id)

        XCTAssertFalse(conversationRepo.conversations.contains(where: { $0.id == toDelete.id }))
        XCTAssertEqual(conversationRepo.conversations.count, 1)
    }

    func testDeleteConversationAlsoDeletesMessages() async throws {
        let conversationRepo = MockConversationRepository()
        let messageRepo = RepoMockForLoad()
        let conv = Conversation(title: "Chat")
        conversationRepo.conversations = [conv]
        messageRepo.stored[conv.id] = [Message(role: .user, text: "hi")]

        let useCase = DefaultDeleteConversationUseCase(
            conversationRepository: conversationRepo,
            messageRepository: messageRepo
        )

        try await useCase.execute(id: conv.id)

        XCTAssertNil(messageRepo.stored[conv.id])
        XCTAssertTrue(conversationRepo.conversations.isEmpty)
    }

    func testDeleteConversationWrapsDomainError() async throws {
        let conversationRepo = MockConversationRepository()
        let messageRepo = RepoMockForLoad()
        let conv = Conversation(title: "Will fail")
        conversationRepo.conversations = [conv]
        conversationRepo.shouldThrowOnDelete = true

        let useCase = DefaultDeleteConversationUseCase(
            conversationRepository: conversationRepo,
            messageRepository: messageRepo
        )

        do {
            try await useCase.execute(id: conv.id)
            XCTFail("Expected DomainError")
        } catch let err as DomainError {
            guard case .repositoryError = err else {
                XCTFail("Wrong domain error case: \(err)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

