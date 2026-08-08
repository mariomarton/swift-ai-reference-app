import Foundation

/// Deterministic `LLMEngine` stub used by simulator and tests.
public final class StubLLMEngine: LLMEngine {
    public init() {}

    public func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        let userMessage = messages.last { $0.role == .user }
        let text = userMessage.map { "\(L10n.StubLLMEngine.responsePrefix) \($0.text)" } ?? L10n.StubLLMEngine.fallbackResponse
        return AsyncThrowingStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }
}
