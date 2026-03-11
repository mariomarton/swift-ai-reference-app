import Foundation

public protocol LoadRecentMessagesUseCase {
    /// Loads recent messages from the repository. If `limit` is provided, returns up to that many of the most recent messages (descending by date).
    func loadRecentMessages(limit: Int?) async throws -> [ChatMessage]
}

public final class DefaultLoadRecentMessagesUseCase: LoadRecentMessagesUseCase {
    private let repository: ChatRepository

    public init(repository: ChatRepository) {
        self.repository = repository
    }

    public func loadRecentMessages(limit: Int?) async throws -> [ChatMessage] {
        do {
            var messages = try await repository.loadRecentMessages()
            messages.sort(by: { $0.date < $1.date }) // ascending
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
