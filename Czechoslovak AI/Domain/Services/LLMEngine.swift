import Foundation

public protocol LLMEngine {
    func generateResponse(for messages: [Message], model: LLMModel?) async throws -> Message
}
