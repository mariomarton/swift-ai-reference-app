import Foundation

public protocol LLMEngine {
    /// Streams the assistant response token by token.
    func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error>
}
