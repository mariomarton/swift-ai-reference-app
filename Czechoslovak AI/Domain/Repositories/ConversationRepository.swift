import Foundation

/// Conversation-level persistence boundary.
/// Placed in `Domain/Services` to group domain service/protocol contracts (LLMEngine, MessageRepository, ConversationRepository).
public protocol ConversationRepository: Sendable {
    /// Create a new conversation with a stable identifier.
    /// Title may be nil for auto-naming.
    func createConversation(id: UUID, title: String?) async throws -> Conversation

    /// Return all conversations, ideally sorted by recent activity (newest first).
    func listConversations() async throws -> [Conversation]
    
    /// Load a specific conversation by ID.
    /// - Parameter id: the conversation ID to load
    /// - Returns: the conversation if it exists
    func loadConversation(id: UUID) async throws -> Conversation?
    
    /// Update an existing conversation (e.g., title, selectedModel, or timestamps).
    /// - Parameter conversation: the conversation with updated fields to persist
    func updateConversation(_ conversation: Conversation) async throws

    /// Permanently delete a conversation by ID.
    /// - Parameter id: the ID of the conversation to delete
    func deleteConversation(id: UUID) async throws
}
