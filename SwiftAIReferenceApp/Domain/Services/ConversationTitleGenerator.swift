import Foundation

public protocol ConversationTitleGenerator {
    /// Generates a concise title from recent conversation context.
    /// Implementations may call an LLM or other summarization mechanism.
    func generateTitle(fromConversationMessages messages: [Message], model: LLMModel?) async throws -> String?
}
