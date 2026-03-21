/// Stub implementation of LLMEngine for development and UI testing.
import Foundation

public final class StubLLMEngine: LLMEngine {
    public init() {}

    public func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        let userMessage = messages.last { $0.role == .user }
        let text: String
        if let userText = userMessage?.text {
            text = "(Stub) Odpoveď na: \(userText)"
        } else {
            text = "(Stub) Toto je ukážková odpoveď od asistenta."
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }
}
