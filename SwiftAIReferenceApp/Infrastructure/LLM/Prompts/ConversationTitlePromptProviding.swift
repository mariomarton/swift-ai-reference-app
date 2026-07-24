import Foundation

public protocol ConversationTitlePromptProviding: Sendable {
    var titleSystemPrompt: String { get }
}

public struct LlamaConversationTitlePromptProvider: ConversationTitlePromptProviding {
    public let titleSystemPrompt: String

    public init() {
        self.titleSystemPrompt = "You are a chat title assistant. When given the user's first message, respond with only a short, descriptive title for the conversation — maximum 45 characters, no quotes, no punctuation at the end, same language as the user's message."
    }
}
