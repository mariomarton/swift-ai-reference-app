import Foundation

public protocol ClearAllMessagesUseCase {
    func clearAll() async throws
}

public final class DefaultClearAllMessagesUseCase: ClearAllMessagesUseCase {
    private let repository: ChatRepository

    public init(repository: ChatRepository) {
        self.repository = repository
    }

    public func clearAll() async throws {
        do {
            try await repository.clearAll()
        } catch {
            throw DomainError.repositoryError(error)
        }
    }
}
