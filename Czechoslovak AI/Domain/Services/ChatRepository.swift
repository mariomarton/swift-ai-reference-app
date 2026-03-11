import Foundation

public protocol ChatRepository {
    func loadRecentMessages() async throws -> [ChatMessage]
    func save(message: ChatMessage) async throws
    func clearAll() async throws
}
