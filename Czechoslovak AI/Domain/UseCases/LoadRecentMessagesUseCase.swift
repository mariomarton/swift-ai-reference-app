import Foundation

public protocol LoadRecentMessagesUseCase {
    /// Loads recent messages from a conversation. If `limit` is provided, returns up to that many of the most recent messages.
    /// - Parameters:
    ///   - conversationID: the conversation to load messages from
    ///   - limit: optional maximum number of recent messages to return
    /// - Returns: array of messages, sorted by date ascending
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
            // Messages are already sorted by repository, but ensure ascending order
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
