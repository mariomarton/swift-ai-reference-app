import Foundation

/// LLM-backed `ConversationTitleGenerator` that normalizes the first response line into a title.
public final class LlamaConversationTitleGenerator: ConversationTitleGenerator {

    private let engine: LLMEngine
    private let promptProvider: any ConversationTitlePromptProviding

    public init(engine: LLMEngine, promptProvider: any ConversationTitlePromptProviding) {
        self.engine = engine
        self.promptProvider = promptProvider
    }

    public func generateTitle(fromConversationMessages messages: [Message], model: LLMModel?) async throws -> String? {
        guard !messages.isEmpty else { return nil }

        let systemPrompt = Message(
            role: .system,
            text: promptProvider.titleSystemPrompt
        )

        // Flatten the transcript into one user turn so title generation does not depend on trailing assistant support.
        let transcript = messages
            .map { "\(label(for: $0.role)): \($0.text)" }
            .joined(separator: "\n")
        let userTurn = Message(role: .user, text: transcript)

        var accumulated = ""
        for try await token in engine.generateResponse(for: [systemPrompt, userTurn], model: model) {
            accumulated += token
            // Stop early once we have enough text for a title.
            if accumulated.count > 200 { break }
        }

        let firstLine = accumulated
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return firstLine?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func label(for role: Message.Role) -> String {
        switch role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }
}