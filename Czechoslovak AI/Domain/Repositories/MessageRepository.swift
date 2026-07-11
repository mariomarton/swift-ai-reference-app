import Foundation

public protocol MessageRepository: Sendable {
    /// Load messages for a specific conversation.
    /// - Parameter conversationID: the conversation to load messages from
    /// - Returns: array of messages for that conversation, sorted by date ascending
    func loadMessages(for conversationID: UUID) async throws -> [Message]
    
    /// Save a message to a specific conversation.
    /// - Parameters:
    ///   - message: the `Message` to save
    ///   - conversationID: the conversation to save the message to
    func save(message: Message, to conversationID: UUID) async throws
    
    /// Clear all messages from a specific conversation.
    /// - Parameter conversationID: the conversation to clear
    func clearMessages(for conversationID: UUID) async throws
    
    /// Clear all messages across all conversations.
    func clearAll() async throws

    /// Permanently delete all messages and storage for a specific conversation.
    /// Unlike `clearMessages(for:)`, this removes the underlying storage entirely.
    /// - Parameter conversationID: the conversation whose message storage should be deleted
    func deleteMessages(for conversationID: UUID) async throws
}
