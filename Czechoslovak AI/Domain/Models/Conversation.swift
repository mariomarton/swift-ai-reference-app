import Foundation

public struct Conversation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String?
    public var messages: [Message]
    public var selectedModel: LLMModel?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = .init(), title: String? = nil, messages: [Message] = [], selectedModel: LLMModel? = nil, createdAt: Date = .init(), updatedAt: Date = .init()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.selectedModel = selectedModel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public mutating func append(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }

    public var lastMessage: Message? {
        messages.last
    }
}
