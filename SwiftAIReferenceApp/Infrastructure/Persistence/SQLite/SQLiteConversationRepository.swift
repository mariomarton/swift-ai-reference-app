import Foundation

public final class SQLiteConversationRepository: ConversationRepository, @unchecked Sendable {
    private let store: SQLiteConversationMessageStore

    init(store: SQLiteConversationMessageStore) {
        self.store = store
    }

    public func createConversation(id: UUID, title: String?) async throws -> Conversation {
        try store.createConversation(id: id, title: title)
        guard let conversation = try store.loadConversation(id: id) else {
            throw SQLiteStorageError.failedToExecuteStatement("Conversation could not be loaded after creation")
        }
        return conversation
    }

    public func listConversations() async throws -> [Conversation] {
        try store.listConversations()
    }

    public func loadConversation(id: UUID) async throws -> Conversation? {
        try store.loadConversation(id: id)
    }

    public func updateConversation(_ conversation: Conversation) async throws {
        try store.updateConversation(conversation)
    }

    public func deleteConversation(id: UUID) async throws {
        try store.deleteConversation(id: id)
    }
}
