import Foundation

public protocol MessageRepository {
    func loadRecentMessages() async throws -> [Message]
    func save(message: Message) async throws
    func clearAll() async throws
}
