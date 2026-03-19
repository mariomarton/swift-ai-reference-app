import Foundation

/// Conversation-level persistence boundary.
/// Placed in `Domain/Services` to group domain service/protocol contracts (LLMEngine, MessageRepository, ConversationRepository).
public protocol ConversationRepository {
    /// Create a new conversation; title may be nil for auto-naming.
    func createConversation(title: String?) async throws -> Conversation

    /// Return all conversations, ideally sorted by recent activity (newest first).
    func listConversations() async throws -> [Conversation]

    /// Optionally implement other operations in infrastructure: update, delete, append message, etc.
}
