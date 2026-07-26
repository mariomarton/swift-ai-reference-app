import Foundation

public protocol SendMessageUseCase {
    /// Persists the user message, streams the assistant reply, and stores the completed response.
    func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error>
}

/// Coordinates persistence, prompt assembly, engine streaming, and best-effort auto-titling.
public final class DefaultSendMessageUseCase: SendMessageUseCase, @unchecked Sendable {
    private let repository: MessageRepository
    private let conversationRepository: ConversationRepository
    private let engine: LLMEngine
    private let promptSettingsRepository: PromptSettingsRepository?
    private let generateTitleUseCase: GenerateConversationTitleUseCase?

    public init(
        repository: MessageRepository,
        conversationRepository: ConversationRepository,
        engine: LLMEngine,
        promptSettingsRepository: PromptSettingsRepository? = nil,
        generateTitleUseCase: GenerateConversationTitleUseCase? = nil
    ) {
        self.repository = repository
        self.conversationRepository = conversationRepository
        self.engine = engine
        self.promptSettingsRepository = promptSettingsRepository
        self.generateTitleUseCase = generateTitleUseCase
    }

    public func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let workerTask = Task(priority: .utility) { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                do {
                    try Task.checkCancellation()
                    let conversationExists = try await conversationRepository.loadConversation(id: conversationID) != nil
                    try await repository.save(message: message, to: conversationID)

                    if !conversationExists {
                        do {
                            _ = try await conversationRepository.createConversation(id: conversationID, title: nil)
                        } catch {
                            try await repository.deleteMessages(for: conversationID)
                            continuation.finish(throwing: DomainError.repositoryError(error))
                            return
                        }
                    }
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    continuation.finish(throwing: DomainError.repositoryError(error))
                    return
                }

                let settings = promptSettingsRepository?.loadSettings() ?? PromptSettings()
                let systemMessage = Message(role: .system, text: settings.composedSystemPrompt)

                let history: [Message]
                do {
                    try Task.checkCancellation()
                    history = try await repository.loadMessages(for: conversationID)
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    continuation.finish(throwing: DomainError.repositoryError(error))
                    return
                }

                let messagesForEngine = history.first?.role == .system ? history : [systemMessage] + history

                var accumulated = ""
                do {
                    for try await token in engine.generateResponse(for: messagesForEngine, model: model) {
                        try Task.checkCancellation()
                        accumulated += token
                        continuation.yield(token)
                    }
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    continuation.finish(throwing: DomainError.engineError(error))
                    return
                }

                do {
                    try Task.checkCancellation()
                    let assistantText = accumulated
                    let assistantMessage = Message(role: .assistant, text: assistantText)
                    try await repository.save(message: assistantMessage, to: conversationID)
                    await tryAutoNameConversation(conversationID: conversationID, model: model)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: DomainError.repositoryError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                workerTask.cancel()
            }
        }
    }

    private func tryAutoNameConversation(
        conversationID: UUID,
        model: LLMModel?
    ) async {
        guard let generateTitleUseCase else { return }

        do {
            guard var conversation = try await conversationRepository.loadConversation(id: conversationID) else {
                return
            }

            let title = await generateTitleUseCase.generateTitle(
                existingTitle: conversation.title,
                titleOrigin: conversation.titleOrigin,
                conversationMessages: try await repository.loadMessages(for: conversationID),
                model: model
            )

            guard let title else { return }

            conversation.title = title
            conversation.titleOrigin = .autoGenerated
            try await conversationRepository.updateConversation(conversation)
        } catch {
            // Title generation is best-effort and must never block chat flow.
        }
    }
}
