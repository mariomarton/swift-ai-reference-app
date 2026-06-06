import Foundation

public protocol SendMessageUseCase {
    /// Persists the user message, then returns a stream of response tokens from the engine.
    /// The completed assistant message is persisted when the stream finishes successfully.
    /// Errors (repository or engine) are thrown via the stream.
    /// - Parameters:
    ///   - message: the user `Message` to send (role should be `.user`)
    ///   - conversationID: the conversation to add the message to
    ///   - model: optional selected model to use
    /// - Returns: stream of response tokens
    func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error>
}

public final class DefaultSendMessageUseCase: SendMessageUseCase {
    private let repository: MessageRepository
    private let conversationRepository: ConversationRepository
    private let engine: LLMEngine
    private let generateTitleUseCase: GenerateConversationTitleUseCase?

    public init(
        repository: MessageRepository,
        conversationRepository: ConversationRepository,
        engine: LLMEngine,
        generateTitleUseCase: GenerateConversationTitleUseCase? = nil
    ) {
        self.repository = repository
        self.conversationRepository = conversationRepository
        self.engine = engine
        self.generateTitleUseCase = generateTitleUseCase
    }

    public func send(message: Message, to conversationID: UUID, model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let workerTask = Task.detached(priority: .utility) { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                // Persist user message first
                do {
                    try Task.checkCancellation()
                    try await repository.save(message: message, to: conversationID)
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    continuation.finish(throwing: DomainError.repositoryError(error))
                    return
                }

                // Auto-name on first user message (non-fatal: never blocks chat flow)
                await tryAutoNameConversation(
                    conversationID: conversationID,
                    firstUserMessageText: message.text,
                    model: model
                )

                // Load full conversation history so the engine has context
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

                // Stream tokens from engine, accumulating the full response for persistence
                var accumulated = ""
                do {
                    for try await token in engine.generateResponse(for: history, model: model) {
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

                // Persist completed assistant message
                do {
                    try Task.checkCancellation()
                    let assistantMessage = Message(role: .assistant, text: accumulated)
                    try await repository.save(message: assistantMessage, to: conversationID)
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

    // MARK: - Private

    private func tryAutoNameConversation(
        conversationID: UUID,
        firstUserMessageText: String,
        model: LLMModel?
    ) async {
        guard let generateTitleUseCase else { return }

        do {
            guard var conversation = try await conversationRepository.loadConversation(id: conversationID) else {
                return
            }

            let title = await generateTitleUseCase.execute(
                existingTitle: conversation.title,
                firstUserMessageText: firstUserMessageText,
                model: model
            )

            guard let title else { return }

            conversation.title = title
            try await conversationRepository.updateConversation(conversation)
        } catch {
            // Intentionally non-fatal. Title generation failure must never affect chat flow.
        }
    }
}
