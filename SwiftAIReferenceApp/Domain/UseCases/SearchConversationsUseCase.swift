import Foundation

public protocol SearchConversationsUseCase {
    /// Returns conversations whose title or message contents match the query.
    func search(conversations: [Conversation], query: String) -> [Conversation]
}

public final class DefaultSearchConversationsUseCase: SearchConversationsUseCase {
    public init() {}

    public func search(conversations: [Conversation], query: String) -> [Conversation] {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty else {
            return conversations
        }

        return conversations.filter { conversation in
            Self.matches(conversation, normalizedQuery: normalizedQuery)
        }
    }

    private static func matches(_ conversation: Conversation, normalizedQuery: String) -> Bool {
        let searchableText = [
            conversation.title ?? "",
            conversation.messages.map(\.text).joined(separator: "\n")
        ]
        .joined(separator: "\n")

        return normalize(searchableText).contains(normalizedQuery)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
