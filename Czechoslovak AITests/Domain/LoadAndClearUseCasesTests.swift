import XCTest
@testable import Czechoslovak_AI

final class RepoMockForLoad: ChatRepository {
    var stored: [ChatMessage] = []
    var shouldThrowOnLoad = false

    func loadRecentMessages() async throws -> [ChatMessage] {
        if shouldThrowOnLoad { throw NSError(domain: "repo", code: 2) }
        return stored
    }

    func save(message: ChatMessage) async throws {
        stored.append(message)
    }

    func clearAll() async throws {
        stored.removeAll()
    }
}

final class LoadAndClearUseCasesTests: XCTestCase {
    func testLoadRecentMessagesWithoutLimitReturnsAllSorted() async throws {
        let repo = RepoMockForLoad()
        let now = Date()
        let older = ChatMessage(role: .user, text: "old", date: now.addingTimeInterval(-60))
        let recent = ChatMessage(role: .assistant, text: "new", date: now)
        repo.stored = [recent, older]

        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)
        let loaded = try await useCase.loadRecentMessages(limit: nil)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0], older)
        XCTAssertEqual(loaded[1], recent)
    }

    func testLoadWithLimitReturnsMostRecentN() async throws {
        let repo = RepoMockForLoad()
        let now = Date()
        let m1 = ChatMessage(role: .user, text: "1", date: now.addingTimeInterval(-300))
        let m2 = ChatMessage(role: .user, text: "2", date: now.addingTimeInterval(-200))
        let m3 = ChatMessage(role: .assistant, text: "3", date: now.addingTimeInterval(-100))
        repo.stored = [m1, m2, m3]

        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)
        let loaded = try await useCase.loadRecentMessages(limit: 2)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0], m2)
        XCTAssertEqual(loaded[1], m3)
    }

    func testClearAllRemovesAll() async throws {
        let repo = RepoMockForLoad()
        repo.stored = [ChatMessage(role: .user, text: "x")]
        let clear = DefaultClearAllMessagesUseCase(repository: repo)

        try await clear.clearAll()
        XCTAssertTrue(repo.stored.isEmpty)
    }

    func testLoadThrowsWrappedError() async throws {
        let repo = RepoMockForLoad()
        repo.shouldThrowOnLoad = true
        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)

        do {
            _ = try await useCase.loadRecentMessages(limit: nil)
            XCTFail("Expected to throw")
        } catch let err as DomainError {
            switch err {
            case .repositoryError:
                break // expected
            default:
                XCTFail("Wrong domain error case")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
