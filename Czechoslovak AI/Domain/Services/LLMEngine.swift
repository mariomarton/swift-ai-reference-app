import Foundation

public protocol LLMEngine {
    func generateResponse(for messages: [ChatMessage], model: LLMModel?) async throws -> ChatMessage
}
