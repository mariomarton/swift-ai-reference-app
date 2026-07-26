import Foundation

public protocol LoadConversationsUseCase {
    /// Loads conversations for the sidebar.
    func loadConversations() async throws -> [Conversation]
}

public final class DefaultLoadConversationsUseCase: LoadConversationsUseCase {
    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func loadConversations() async throws -> [Conversation] {
        return try await repository.listConversations()
    }
}
