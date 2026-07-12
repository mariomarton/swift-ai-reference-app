import Foundation

public protocol ConversationTitleGenerator {
    /// Generates a concise title from the first user message text.
    /// Implementations may call an LLM or other summarization mechanism.
    func generateTitle(fromFirstUserMessage text: String, model: LLMModel?) async throws -> String?
}
