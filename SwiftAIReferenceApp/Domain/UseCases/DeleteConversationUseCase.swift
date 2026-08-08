import Foundation

public protocol DeleteConversationUseCase {
    /// Deletes a conversation and its associated messages.
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
            // Delete messages first so a failure leaves the conversation record intact.
            try await messageRepository.deleteMessages(for: id)
            try await conversationRepository.deleteConversation(id: id)
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
