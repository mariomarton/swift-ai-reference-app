import Foundation

public final class SQLiteMessageRepository: MessageRepository, @unchecked Sendable {
    private let store: SQLiteConversationMessageStore

    init(store: SQLiteConversationMessageStore) {
        self.store = store
    }

    public func loadMessages(for conversationID: UUID) async throws -> [Message] {
        try store.loadMessages(for: conversationID)
    }

    public func save(message: Message, to conversationID: UUID) async throws {
        try store.saveMessage(message, to: conversationID)
    }

    public func clearMessages(for conversationID: UUID) async throws {
        try store.clearMessages(for: conversationID)
    }

    public func clearAll() async throws {
        try store.clearAllMessages()
    }

    public func deleteMessages(for conversationID: UUID) async throws {
        try store.deleteMessages(for: conversationID)
    }
}
