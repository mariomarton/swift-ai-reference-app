import Foundation

/// Persistence boundary for conversations.
public protocol ConversationRepository: Sendable {
    /// Creates and persists a conversation record.
    func createConversation(id: UUID, title: String?) async throws -> Conversation

    /// Lists conversations in recency order.
    func listConversations() async throws -> [Conversation]

    /// Loads a conversation by identifier.
    func loadConversation(id: UUID) async throws -> Conversation?

    /// Persists changes to an existing conversation.
    func updateConversation(_ conversation: Conversation) async throws

    /// Permanently deletes a conversation record.
    func deleteConversation(id: UUID) async throws
}
