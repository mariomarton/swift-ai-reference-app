import Foundation

public struct Conversation: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String?
    public var messages: [ChatMessage]
    public var selectedModel: LLMModel?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = .init(), title: String? = nil, messages: [ChatMessage] = [], selectedModel: LLMModel? = nil, createdAt: Date = .init(), updatedAt: Date = .init()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.selectedModel = selectedModel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public mutating func append(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    public var lastMessage: ChatMessage? {
        messages.last
    }
}
