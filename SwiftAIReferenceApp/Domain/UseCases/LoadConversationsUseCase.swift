import Foundation

public protocol LoadConversationsUseCase {
    /// Loads a list of conversations for display (e.g., list screen).
    func execute() async throws -> [Conversation]
}

public final class DefaultLoadConversationsUseCase: LoadConversationsUseCase {
    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Conversation] {
        return try await repository.listConversations()
    }
}
