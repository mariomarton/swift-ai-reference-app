import XCTest
@testable import Czechoslovak_AI

final class MockChatRepository: ChatRepository {
    var stored: [ChatMessage] = []
    var shouldThrowOnSave: Bool = false

    func loadRecentMessages() async throws -> [ChatMessage] {
        return stored
    }

    func save(message: ChatMessage) async throws {
        if shouldThrowOnSave { throw DomainError.repositoryError(NSError(domain: "mock", code: 1)) }
        stored.append(message)
    }

    func clearAll() async throws {
        stored.removeAll()
    }
}

final class MockLLMEngine: LLMEngine {
    var responseToReturn: ChatMessage?
    var shouldThrow: Bool = false

    func generateResponse(for messages: [ChatMessage], model: LLMModel?) async throws -> ChatMessage {
        if shouldThrow { throw NSError(domain: "llm", code: 2) }
        if let resp = responseToReturn { return resp }
        return ChatMessage(role: .assistant, text: "Default reply")
    }
}

final class SendMessageUseCaseTests: XCTestCase {
    func testSendMessageHappyPath() async throws {
        let repo = MockChatRepository()
        let engine = MockLLMEngine()
        let useCase = DefaultSendMessageUseCase(repository: repo, engine: engine)

        let user = ChatMessage(role: .user, text: "Ahoj")
        let assistant = ChatMessage(role: .assistant, text: "Ahoj! Ako môžem pomôcť?")
        engine.responseToReturn = assistant

        let returned = try await useCase.send(message: user, model: nil)

        XCTAssertEqual(returned, assistant)
        XCTAssertEqual(repo.stored.count, 2)
        XCTAssertEqual(repo.stored[0], user)
        XCTAssertEqual(repo.stored[1], assistant)
    }

    func testEngineErrorIsWrapped() async throws {
        let repo = MockChatRepository()
        let engine = MockLLMEngine()
        engine.shouldThrow = true
        let useCase = DefaultSendMessageUseCase(repository: repo, engine: engine)

        let user = ChatMessage(role: .user, text: "Hello")

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
