import Foundation

public protocol CreateConversationUseCase {
    /// Creates a conversation and returns the created entity.
    func execute(title: String?) async throws -> Conversation
}

public final class DefaultCreateConversationUseCase: CreateConversationUseCase {
    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func execute(title: String?) async throws -> Conversation {
        // In the future, add validation or analytics here
        return try await repository.createConversation(title: title)
    }
}
