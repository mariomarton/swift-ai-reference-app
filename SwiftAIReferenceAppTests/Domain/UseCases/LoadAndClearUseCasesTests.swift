import XCTest
@testable import SwiftAIReferenceApp

final class RepoMockForLoad: MessageRepository, @unchecked Sendable {
    var stored: [UUID: [Message]] = [:]
    var shouldThrowOnLoad = false

    func loadMessages(for conversationID: UUID) async throws -> [Message] {
        if shouldThrowOnLoad { throw NSError(domain: "repo", code: 2) }
        return stored[conversationID] ?? []
    }

    func save(message: Message, to conversationID: UUID) async throws {
        if stored[conversationID] == nil {
            stored[conversationID] = []
        }
        stored[conversationID]?.append(message)
    }

    func clearMessages(for conversationID: UUID) async throws {
        stored[conversationID] = []
    }

    func clearAll() async throws {
        stored.removeAll()
    }

    func deleteMessages(for conversationID: UUID) async throws {
        stored.removeValue(forKey: conversationID)
    }
}

@MainActor
final class LoadAndClearUseCasesTests: XCTestCase {
    func testLoadRecentMessagesWithLimit() async throws {
        let repo = RepoMockForLoad()
        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)

        let conversationID = UUID()
        let messages = (0..<10).map { i in
            Message(role: .user, text: "Message \(i)", date: Date(timeIntervalSince1970: TimeInterval(i)))
        }

        for msg in messages {
            try await repo.save(message: msg, to: conversationID)
        }

        let loaded = try await useCase.loadRecentMessages(for: conversationID, limit: 3)
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].text, "Message 7")
        XCTAssertEqual(loaded[1].text, "Message 8")
        XCTAssertEqual(loaded[2].text, "Message 9")
    }

    func testLoadRecentMessagesNoLimit() async throws {
        let repo = RepoMockForLoad()
        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)

        let conversationID = UUID()
        let messages = (0..<5).map { i in
            Message(role: .assistant, text: "Reply \(i)", date: Date(timeIntervalSince1970: TimeInterval(i)))
        }

        for msg in messages {
            try await repo.save(message: msg, to: conversationID)
        }

        let loaded = try await useCase.loadRecentMessages(for: conversationID, limit: nil)
        XCTAssertEqual(loaded.count, 5)
    }

    func testLoadMessagesFromDifferentConversations() async throws {
        let repo = RepoMockForLoad()
        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)

        let conv1 = UUID()
        let conv2 = UUID()

        let msg1 = Message(role: .user, text: "Conv1 Msg1")
        let msg2 = Message(role: .user, text: "Conv2 Msg1")

        try await repo.save(message: msg1, to: conv1)
        try await repo.save(message: msg2, to: conv2)

        let loaded1 = try await useCase.loadRecentMessages(for: conv1, limit: nil)
        let loaded2 = try await useCase.loadRecentMessages(for: conv2, limit: nil)

        XCTAssertEqual(loaded1.count, 1)
        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded1[0].text, "Conv1 Msg1")
        XCTAssertEqual(loaded2[0].text, "Conv2 Msg1")
    }

    func testClearAllRemovesAll() async throws {
        let repo = RepoMockForLoad()
        let conv1 = UUID()
        try await repo.save(message: Message(role: .user, text: "x"), to: conv1)
        let clear = DefaultClearAllMessagesUseCase(repository: repo)

        try await clear.clearAll()
        XCTAssertTrue(repo.stored.isEmpty)
    }

    func testLoadThrowsWrappedError() async throws {
        let repo = RepoMockForLoad()
        repo.shouldThrowOnLoad = true
        let useCase = DefaultLoadRecentMessagesUseCase(repository: repo)

        do {
            _ = try await useCase.loadRecentMessages(for: UUID(), limit: nil)
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
