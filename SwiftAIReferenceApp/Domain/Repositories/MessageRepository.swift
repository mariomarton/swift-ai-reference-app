import Foundation

public protocol MessageRepository: Sendable {
    /// Loads messages for a conversation in ascending date order.
    func loadMessages(for conversationID: UUID) async throws -> [Message]

    /// Saves a message to a conversation.
    func save(message: Message, to conversationID: UUID) async throws

    /// Clears the stored messages for one conversation.
    func clearMessages(for conversationID: UUID) async throws

    /// Clears all stored messages across every conversation.
    func clearAll() async throws

    /// Permanently deletes a conversation's message storage.
    /// Unlike `clearMessages(for:)`, this removes the underlying files too.
    func deleteMessages(for conversationID: UUID) async throws
}
