import Foundation

public protocol LoadRecentMessagesUseCase {
    /// Loads recent messages from a conversation in ascending date order.
    func loadRecentMessages(for conversationID: UUID, limit: Int?) async throws -> [Message]
}

public final class DefaultLoadRecentMessagesUseCase: LoadRecentMessagesUseCase {
    private let repository: MessageRepository

    public init(repository: MessageRepository) {
        self.repository = repository
    }

    public func loadRecentMessages(for conversationID: UUID, limit: Int?) async throws -> [Message] {
        do {
            var messages = try await repository.loadMessages(for: conversationID)
            // Normalize ordering so callers do not depend on repository-specific sort behavior.
            messages.sort(by: { $0.date < $1.date })
            if let limit = limit, limit > 0 {
                let start = max(0, messages.count - limit)
                return Array(messages[start..<messages.count])
            }
            return messages
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
