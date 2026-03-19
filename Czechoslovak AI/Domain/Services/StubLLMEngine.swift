/// Stub implementation of LLMEngine for development and UI testing.
import Foundation

public final class StubLLMEngine: LLMEngine {
    public init() {}

    public func generateResponse(for messages: [Message], model: LLMModel?) async throws -> Message {
        // Find the last user message if available
        let userMessage = messages.last { $0.role == .user }
        let baseResponse: String
        if let text = userMessage?.text {
            baseResponse = "(Stub) Odpověď na: \(text)"
        } else {
            baseResponse = "(Stub) Toto je ukázková odpověď od asistenta."
        }
        return Message(role: .assistant, text: baseResponse)
    }
}
