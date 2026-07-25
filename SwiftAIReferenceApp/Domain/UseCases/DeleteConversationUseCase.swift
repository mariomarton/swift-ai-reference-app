import Foundation

public protocol DeleteConversationUseCase {
    /// Permanently delete a conversation and all its associated messages.
    /// - Parameter id: the ID of the conversation to delete
    func deleteConversation(id: UUID) async throws
}

public final class DefaultDeleteConversationUseCase: DeleteConversationUseCase {
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository

    public init(conversationRepository: ConversationRepository, messageRepository: MessageRepository) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    public func deleteConversation(id: UUID) async throws {
        do {
            // Delete messages first; if this fails the conversation entry is still intact (safer rollback)
            try await messageRepository.deleteMessages(for: id)
            try await conversationRepository.deleteConversation(id: id)
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
