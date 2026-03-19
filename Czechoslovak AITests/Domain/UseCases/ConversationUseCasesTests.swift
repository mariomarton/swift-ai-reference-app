import XCTest
@testable import Czechoslovak_AI

final class MockConversationRepository: ConversationRepository {
    var conversations: [Conversation] = []
    var shouldThrowOnCreate = false

    func createConversation(title: String?) async throws -> Conversation {
        if shouldThrowOnCreate { throw NSError(domain: "mock", code: 1) }
        let conv = Conversation(title: title)
        conversations.append(conv)
        return conv
    }

    func listConversations() async throws -> [Conversation] {
        return conversations
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
}
