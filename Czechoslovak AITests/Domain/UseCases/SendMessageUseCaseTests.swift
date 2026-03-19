import XCTest
@testable import Czechoslovak_AI

final class MockMessageRepository: MessageRepository {
    var stored: [Message] = []
    var shouldThrowOnSave: Bool = false

    func loadRecentMessages() async throws -> [Message] {
        return stored
    }

    func save(message: Message) async throws {
        if shouldThrowOnSave { throw DomainError.repositoryError(NSError(domain: "mock", code: 1)) }
        stored.append(message)
    }

    func clearAll() async throws {
        stored.removeAll()
    }
}

final class MockLLMEngine: LLMEngine {
    var responseToReturn: Message?
    var shouldThrow: Bool = false

    func generateResponse(for messages: [Message], model: LLMModel?) async throws -> Message {
        if shouldThrow { throw NSError(domain: "llm", code: 2) }
        if let resp = responseToReturn { return resp }
        return Message(role: .assistant, text: "Default reply")
    }
}

@MainActor
final class SendMessageUseCaseTests: XCTestCase {
    func testSendMessageHappyPath() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        let useCase = DefaultSendMessageUseCase(repository: repo, engine: engine)

        let user = Message(role: .user, text: "Ahoj")
        let assistant = Message(role: .assistant, text: "Ahoj! Ako môžem pomôcť?")
        engine.responseToReturn = assistant

        let returned = try await useCase.send(message: user, model: nil)

        XCTAssertEqual(returned, assistant)
        XCTAssertEqual(repo.stored.count, 2)
        XCTAssertEqual(repo.stored[0], user)
        XCTAssertEqual(repo.stored[1], assistant)
    }

    func testEngineErrorIsWrapped() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        engine.shouldThrow = true
        let useCase = DefaultSendMessageUseCase(repository: repo, engine: engine)

        let user = Message(role: .user, text: "Hello")

        do {
            _ = try await useCase.send(message: user, model: nil)
            XCTFail("Expected error")
        } catch let error as DomainError {
            switch error {
            case .engineError:
                // expected
                break
            default:
                XCTFail("Wrong DomainError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Even if engine failed, the user message should still be persisted
        XCTAssertEqual(repo.stored.count, 1)
    }
}
