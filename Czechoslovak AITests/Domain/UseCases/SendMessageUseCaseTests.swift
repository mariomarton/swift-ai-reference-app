import XCTest
@testable import Czechoslovak_AI

final class MockMessageRepository: MessageRepository {
    func deleteMessages(for conversationID: UUID) async throws {
        stored.removeValue(forKey: conversationID)
    }
    
    var stored: [UUID: [Message]] = [:] // Track messages per conversation
    var shouldThrowOnSave: Bool = false

    func loadMessages(for conversationID: UUID) async throws -> [Message] {
        return stored[conversationID] ?? []
    }

    func save(message: Message, to conversationID: UUID) async throws {
        if shouldThrowOnSave { throw DomainError.repositoryError(NSError(domain: "mock", code: 1)) }
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
}

final class MockGenerateConversationTitleUseCase: GenerateConversationTitleUseCase {
    var titleToReturn: String?
    private(set) var invocationCount = 0
    private(set) var capturedExistingTitle: String??
    private(set) var capturedMessageText: String?

    func execute(existingTitle: String?, firstUserMessageText: String, model: LLMModel?) async -> String? {
        invocationCount += 1
        capturedExistingTitle = existingTitle
        capturedMessageText = firstUserMessageText
        // Mirror real policy: return nil when a title already exists
        if let existing = existingTitle, !existing.isEmpty { return nil }
        return titleToReturn
    }
}

final class MockLLMEngine: LLMEngine {
    var tokensToYield: [String] = ["Default reply"]
    var shouldThrow = false
    private(set) var capturedContexts: [[Message]] = []

    func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        capturedContexts.append(messages)
        let tokens = tokensToYield
        let shouldThrow = self.shouldThrow
        return AsyncThrowingStream { continuation in
            if shouldThrow {
                continuation.finish(throwing: NSError(domain: "llm", code: 2))
            } else {
                for token in tokens { continuation.yield(token) }
                continuation.finish()
            }
        }
    }
}

// MARK: - Helpers

private func makeSendUseCase(
    messageRepo: MockMessageRepository = MockMessageRepository(),
    conversationRepo: MockConversationRepository = MockConversationRepository(),
    engine: MockLLMEngine = MockLLMEngine(),
    titleUseCase: GenerateConversationTitleUseCase? = nil
) -> DefaultSendMessageUseCase {
    DefaultSendMessageUseCase(
        repository: messageRepo,
        conversationRepository: conversationRepo,
        engine: engine,
        generateTitleUseCase: titleUseCase
    )
}

@MainActor
final class SendMessageUseCaseTests: XCTestCase {
    func testSendMessageHappyPath() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: repo, engine: engine)

        let conversationID = UUID()
        let user = Message(role: .user, text: "Ahoj")
        engine.tokensToYield = ["Ahoj! Ako môžem pomôcť?"]

        var collected = ""
        for try await token in useCase.send(message: user, to: conversationID, model: nil) {
            collected += token
        }

        XCTAssertEqual(collected, "Ahoj! Ako môžem pomôcť?")
        let messages = repo.stored[conversationID] ?? []
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], user)
        XCTAssertEqual(messages[1].text, "Ahoj! Ako môžem pomôcť?")
        XCTAssertEqual(messages[1].role, .assistant)

        // Engine should have received the full history at call time (just the user message here)
        XCTAssertEqual(engine.capturedContexts.count, 1)
        XCTAssertEqual(engine.capturedContexts[0], [user])
    }

    func testEngineErrorIsWrapped() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        engine.shouldThrow = true
        let useCase = makeSendUseCase(messageRepo: repo, engine: engine)

        let conversationID = UUID()
        let user = Message(role: .user, text: "Hello")

        do {
            for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}
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
        let messages = repo.stored[conversationID] ?? []
        XCTAssertEqual(messages.count, 1)
    }

    func testEngineReceivesFullConversationHistory() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: repo, engine: engine)

        let conversationID = UUID()

        // Seed two prior turns directly into the repository
        let prior1 = Message(role: .user, text: "Prvá otázka")
        let prior2 = Message(role: .assistant, text: "Prvá odpoveď")
        try await repo.save(message: prior1, to: conversationID)
        try await repo.save(message: prior2, to: conversationID)

        let newUserMessage = Message(role: .user, text: "Druhá otázka")
        for try await _ in useCase.send(message: newUserMessage, to: conversationID, model: nil) {}

        // Engine must receive all three messages: the two prior turns + the new user message
        XCTAssertEqual(engine.capturedContexts.count, 1)
        let context = engine.capturedContexts[0]
        XCTAssertEqual(context.count, 3)
        XCTAssertEqual(context[0], prior1)
        XCTAssertEqual(context[1], prior2)
        XCTAssertEqual(context[2], newUserMessage)
    }

    func testMessagesIsolatedByConversation() async throws {
        let repo = MockMessageRepository()
        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: repo, engine: engine)

        let conv1 = UUID()
        let conv2 = UUID()

        let msg1User = Message(role: .user, text: "Conversation 1")
        engine.tokensToYield = ["Reply 1"]
        for try await _ in useCase.send(message: msg1User, to: conv1, model: nil) {}

        let msg2User = Message(role: .user, text: "Conversation 2")
        engine.tokensToYield = ["Reply 2"]
        for try await _ in useCase.send(message: msg2User, to: conv2, model: nil) {}

        // Verify isolation
        XCTAssertEqual(repo.stored[conv1]?.count, 2)
        XCTAssertEqual(repo.stored[conv2]?.count, 2)
        XCTAssertEqual(repo.stored[conv1]?[0].text, "Conversation 1")
        XCTAssertEqual(repo.stored[conv2]?[0].text, "Conversation 2")
    }

    // MARK: - Auto-title orchestration

    func testAutoTitleIsGeneratedAndPersistedOnFirstMessage() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = MockConversationRepository()
        let conv = Conversation(title: nil)
        convRepo.conversations = [conv]

        let titleUseCase = MockGenerateConversationTitleUseCase()
        titleUseCase.titleToReturn = "Dane pre s.r.o."

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: titleUseCase)

        let user = Message(role: .user, text: "Ako fungujú dane pre s.r.o.?")
        for try await _ in useCase.send(message: user, to: conv.id, model: nil) {}

        XCTAssertEqual(titleUseCase.invocationCount, 1)
        XCTAssertEqual(titleUseCase.capturedMessageText, "Ako fungujú dane pre s.r.o.?")
        XCTAssertEqual(convRepo.conversations.first?.title, "Dane pre s.r.o.")
    }

    func testAutoTitleIsNotRetriggeredOnSubsequentMessages() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = MockConversationRepository()
        let conv = Conversation(title: "Existujúci názov")
        convRepo.conversations = [conv]

        let titleUseCase = MockGenerateConversationTitleUseCase()
        titleUseCase.titleToReturn = "Ignorovaný názov"

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: titleUseCase)

        let user = Message(role: .user, text: "Druhá otázka")
        for try await _ in useCase.send(message: user, to: conv.id, model: nil) {}

        // GenerateConversationTitleUseCase is called but returns nil (existing title) — no update
        XCTAssertEqual(titleUseCase.invocationCount, 1)
        XCTAssertEqual(convRepo.conversations.first?.title, "Existujúci názov")
    }

    func testSendSucceedsEvenWhenTitleGenerationFails() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = MockConversationRepository()
        // Conversation not found — title generation will throw internally
        convRepo.conversations = []

        let titleUseCase = MockGenerateConversationTitleUseCase()
        titleUseCase.titleToReturn = "X"

        let engine = MockLLMEngine()
        engine.tokensToYield = ["Odpoveď"]
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: titleUseCase)

        let convID = UUID()
        let user = Message(role: .user, text: "Otázka")
        var collected = ""
        for try await token in useCase.send(message: user, to: convID, model: nil) {
            collected += token
        }

        // Chat flow must complete successfully despite missing conversation for title
        XCTAssertEqual(collected, "Odpoveď")
        XCTAssertEqual(messageRepo.stored[convID]?.count, 2)
    }

    func testAutoTitleIsNotAppliedWhenUseCaseIsNil() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = MockConversationRepository()
        let conv = Conversation(title: nil)
        convRepo.conversations = [conv]

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: nil)

        let user = Message(role: .user, text: "Otázka")
        for try await _ in useCase.send(message: user, to: conv.id, model: nil) {}

        XCTAssertNil(convRepo.conversations.first?.title)
    }
}
