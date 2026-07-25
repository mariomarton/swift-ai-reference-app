import Foundation

public protocol LoadConversationsUseCase {
    /// Loads a list of conversations for display (e.g., list screen).
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
