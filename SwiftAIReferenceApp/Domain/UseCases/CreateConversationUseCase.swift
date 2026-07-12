import Foundation

public protocol CreateConversationUseCase {
    /// Creates a conversation with the supplied identifier and returns the created entity.
    func execute(id: UUID, title: String?) async throws -> Conversation
}

public final class DefaultCreateConversationUseCase: CreateConversationUseCase {
    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func execute(id: UUID, title: String?) async throws -> Conversation {
        return try await repository.createConversation(id: id, title: title)
    }
}
