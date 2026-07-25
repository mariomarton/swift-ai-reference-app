import Foundation

public protocol ClearAllMessagesUseCase {
    func clearAllMessages() async throws
}

public final class DefaultClearAllMessagesUseCase: ClearAllMessagesUseCase {
    private let repository: MessageRepository

    public init(repository: MessageRepository) {
        self.repository = repository
    }

    public func clearAllMessages() async throws {
        do {
            try await repository.clearAll()
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
