import Foundation

public protocol SendMessageUseCase {
    /// Sends a user message, persists it, asks the LLM engine to generate a response, persists the assistant response, and returns the assistant message.
    /// - Parameters:
    ///   - message: the user `ChatMessage` to send (role should be `.user`)
    ///   - model: optional selected model to use
    /// - Returns: assistant `ChatMessage`
    func send(message: ChatMessage, model: LLMModel?) async throws -> ChatMessage
}

public final class DefaultSendMessageUseCase: SendMessageUseCase {
    private let repository: ChatRepository
    private let engine: LLMEngine

    public init(repository: ChatRepository, engine: LLMEngine) {
        self.repository = repository
        self.engine = engine
    }

    public func send(message: ChatMessage, model: LLMModel?) async throws -> ChatMessage {
        // Persist user message first
        try await repository.save(message: message)

        // Ask engine for a response
        do {
            let assistant = try await engine.generateResponse(for: [message], model: model)
            try await repository.save(message: assistant)
            return assistant
        } catch {
            // Wrap engine errors to DomainError so higher layers can react predictably
            throw DomainError.engineError(error)
        }
    }
}
