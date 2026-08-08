import Foundation

public protocol RenameConversationUseCase {
    /// Renames an existing conversation and marks it as user-managed.
    func renameConversation(id: UUID, title: String) async throws -> Conversation
}

public final class DefaultRenameConversationUseCase: RenameConversationUseCase {
    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func renameConversation(id: UUID, title: String) async throws -> Conversation {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw DomainError.invalidConversationTitle
        }

        do {
            guard var conversation = try await repository.loadConversation(id: id) else {
                throw DomainError.conversationNotFound
            }

            let currentTitle = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle == normalizedTitle, conversation.titleOrigin == .manual {
                return conversation
            }

            conversation.rename(to: normalizedTitle)
            try await repository.updateConversation(conversation)
            return conversation
        } catch let domainError as DomainError {
            throw domainError
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
