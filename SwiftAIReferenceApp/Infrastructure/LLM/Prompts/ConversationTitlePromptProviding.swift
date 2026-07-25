import Foundation

public protocol ConversationTitlePromptProviding: Sendable {
    var titleSystemPrompt: String { get }
}

public struct LlamaConversationTitlePromptProvider: ConversationTitlePromptProviding {
    public let titleSystemPrompt: String

    public init() {
        self.titleSystemPrompt = "You are a chat title assistant. When given recent conversation context, respond with only a short, descriptive title for the conversation — maximum 45 characters, no quotes, no punctuation at the end, and use the same language as the conversation."
    }
}
