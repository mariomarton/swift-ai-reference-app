import XCTest
@testable import SwiftAIReferenceApp

final class MockMessageRepository: MessageRepository, @unchecked Sendable {
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

private final class MockPromptSettingsRepository: PromptSettingsRepository, @unchecked Sendable {
    var settings: PromptSettings = PromptSettings()

    func loadSettings() -> PromptSettings {
        settings
    }

    func saveSettings(_ settings: PromptSettings) {
        self.settings = settings
    }
}

final class SendMessageConversationRepositoryMock: ConversationRepository, @unchecked Sendable {
    var conversations: [Conversation] = []
    var shouldThrowOnCreate = false
    var shouldThrowOnDelete = false
    private(set) var createdConversationIDs: [UUID] = []

    func loadConversation(id: UUID) async throws -> Conversation? {
        conversations.first { $0.id == id }
    }

    func updateConversation(_ conversation: Conversation) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw NSError(domain: "mock", code: 2)
        }
        conversations[index] = conversation
    }

    func createConversation(id: UUID, title: String?) async throws -> Conversation {
        if shouldThrowOnCreate { throw NSError(domain: "mock", code: 1) }
        let conv = Conversation(id: id, title: title)
        createdConversationIDs.append(id)
        conversations.append(conv)
        return conv
    }

    func listConversations() async throws -> [Conversation] {
        conversations
    }

    func deleteConversation(id: UUID) async throws {
        if shouldThrowOnDelete { throw NSError(domain: "mock", code: 3) }
        conversations.removeAll { $0.id == id }
    }
}

// MARK: - Helpers

private func makeSendUseCase(
    messageRepo: MockMessageRepository = MockMessageRepository(),
    conversationRepo: SendMessageConversationRepositoryMock = SendMessageConversationRepositoryMock(),
    engine: MockLLMEngine = MockLLMEngine(),
    promptSettingsRepo: PromptSettingsRepository? = nil,
    titleUseCase: GenerateConversationTitleUseCase? = nil
) -> DefaultSendMessageUseCase {
    DefaultSendMessageUseCase(
        repository: messageRepo,
        conversationRepository: conversationRepo,
        engine: engine,
        promptSettingsRepository: promptSettingsRepo,
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

        // Engine should have received the full history with the default system prompt prepended.
        XCTAssertEqual(engine.capturedContexts.count, 1)
        XCTAssertEqual(engine.capturedContexts[0].count, 2)
        XCTAssertEqual(engine.capturedContexts[0][0].role, .system)
        XCTAssertEqual(engine.capturedContexts[0][0].text, PromptSettings.defaultSystemPrompt)
        XCTAssertEqual(engine.capturedContexts[0][1], user)
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

        // Engine must receive the full history with the default system prompt prepended.
        XCTAssertEqual(engine.capturedContexts.count, 1)
        let context = engine.capturedContexts[0]
        XCTAssertEqual(context.count, 4)
        XCTAssertEqual(context[0].role, .system)
        XCTAssertEqual(context[1], prior1)
        XCTAssertEqual(context[2], prior2)
        XCTAssertEqual(context[3], newUserMessage)
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
        XCTAssertEqual(engine.capturedContexts.count, 2)
        XCTAssertEqual(engine.capturedContexts[0].first?.role, .system)
        XCTAssertEqual(engine.capturedContexts[1].first?.role, .system)
    }

    // MARK: - Auto-title orchestration

    func testAutoTitleIsGeneratedAndPersistedOnFirstMessage() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = SendMessageConversationRepositoryMock()
        let conversationID = UUID()
        let conv = Conversation(id: conversationID, title: nil)
        convRepo.conversations = [conv]

        let titleUseCase = MockGenerateConversationTitleUseCase()
        titleUseCase.titleToReturn = "Dane pre s.r.o."

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: titleUseCase)

        let user = Message(role: .user, text: "Ako fungujú dane pre s.r.o.?")
        for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}

        XCTAssertEqual(titleUseCase.invocationCount, 1)
        XCTAssertEqual(titleUseCase.capturedMessageText, "Ako fungujú dane pre s.r.o.?")
        XCTAssertEqual(convRepo.conversations.first?.title, "Dane pre s.r.o.")
    }

    func testAutoTitleIsNotRetriggeredOnSubsequentMessages() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = SendMessageConversationRepositoryMock()
        let conversationID = UUID()
        let conv = Conversation(id: conversationID, title: "Existujúci názov")
        convRepo.conversations = [conv]

        let titleUseCase = MockGenerateConversationTitleUseCase()
        titleUseCase.titleToReturn = "Ignorovaný názov"

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: titleUseCase)

        let user = Message(role: .user, text: "Druhá otázka")
        for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}

        // GenerateConversationTitleUseCase is called but returns nil (existing title) — no update
        XCTAssertEqual(titleUseCase.invocationCount, 1)
        XCTAssertEqual(convRepo.conversations.first?.title, "Existujúci názov")
    }

    func testSendSucceedsEvenWhenTitleGenerationFails() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = SendMessageConversationRepositoryMock()
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
        let convRepo = SendMessageConversationRepositoryMock()
        let conversationID = UUID()
        let conv = Conversation(id: conversationID, title: nil)
        convRepo.conversations = [conv]

        let engine = MockLLMEngine()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine, titleUseCase: nil)

        let user = Message(role: .user, text: "Otázka")
        for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}

        XCTAssertNil(convRepo.conversations.first?.title)
    }

    func testSendCreatesConversationWhenMissing() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = SendMessageConversationRepositoryMock()
        let engine = MockLLMEngine()
        let conversationID = UUID()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine)

        let user = Message(role: .user, text: "Ahoj")
        for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}

        XCTAssertEqual(convRepo.createdConversationIDs, [conversationID])
        XCTAssertEqual(convRepo.conversations.first?.id, conversationID)
        XCTAssertEqual(messageRepo.stored[conversationID]?.first, user)
    }

    func testSendRollsBackUserMessageWhenConversationCreationFails() async throws {
        let messageRepo = MockMessageRepository()
        let convRepo = SendMessageConversationRepositoryMock()
        convRepo.shouldThrowOnCreate = true
        let engine = MockLLMEngine()
        let conversationID = UUID()
        let useCase = makeSendUseCase(messageRepo: messageRepo, conversationRepo: convRepo, engine: engine)

        let user = Message(role: .user, text: "Ahoj")

        do {
            for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}
            XCTFail("Expected error")
        } catch let error as DomainError {
            guard case .repositoryError = error else {
                XCTFail("Wrong DomainError case: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(messageRepo.stored[conversationID])
        XCTAssertTrue(convRepo.conversations.isEmpty)
    }

    func testConfiguredPromptSettingsArePrependedToConversationHistory() async throws {
        let messageRepo = MockMessageRepository()
        let engine = MockLLMEngine()
        let promptRepo = MockPromptSettingsRepository()
        promptRepo.settings = PromptSettings(
            systemPrompt: "Be direct.",
            customInstructions: "Use bullets.",
            tonePreset: .friendly
        )

        let useCase = makeSendUseCase(
            messageRepo: messageRepo,
            engine: engine,
            promptSettingsRepo: promptRepo
        )

        let conversationID = UUID()
        let user = Message(role: .user, text: "Hello")
        for try await _ in useCase.send(message: user, to: conversationID, model: nil) {}

        XCTAssertEqual(engine.capturedContexts.count, 1)
        let context = engine.capturedContexts[0]
        XCTAssertEqual(context.count, 2)
        XCTAssertEqual(context[0].role, .system)
        XCTAssertTrue(context[0].text.contains("Be direct."))
        XCTAssertTrue(context[0].text.contains("Use a warm, friendly tone."))
        XCTAssertTrue(context[0].text.contains("Use bullets."))
        XCTAssertEqual(context[1], user)
    }
}
