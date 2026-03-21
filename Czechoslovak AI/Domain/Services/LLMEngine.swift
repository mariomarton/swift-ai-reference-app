import Foundation

public protocol LLMEngine {
    /// Returns a stream of text tokens that together form the assistant response.
    func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error>
}
