import Foundation

public protocol SearchConversationsUseCase {
    /// Searches conversation titles and message text with normalized matching.
    func search(conversations: [Conversation], query: String) -> [Conversation]
}

public struct DefaultSearchConversationsUseCase: SearchConversationsUseCase {
    public init() {}

    public func search(conversations: [Conversation], query: String) -> [Conversation] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return conversations
        }

        return conversations.filter { conversation in
            matches(conversation, normalizedQuery: normalizedQuery)
        }
    }

    private func matches(_ conversation: Conversation, normalizedQuery: String) -> Bool {
        let searchableText = [
            conversation.title ?? "",
            conversation.messages.map(\.text).joined(separator: "\n")
        ]
        .joined(separator: "\n")

        return normalize(searchableText).contains(normalizedQuery)
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
