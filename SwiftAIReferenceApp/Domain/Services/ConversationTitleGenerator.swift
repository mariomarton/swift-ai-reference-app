import Foundation

public protocol ConversationTitleGenerator {
    /// Generates a concise title from recent conversation context.
    func generateTitle(fromConversationMessages messages: [Message], model: LLMModel?) async throws -> String?
}
