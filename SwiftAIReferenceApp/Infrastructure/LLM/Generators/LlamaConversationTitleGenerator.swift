import Foundation

/// LLM-backed implementation of `ConversationTitleGenerator`.
///
/// Sends a short title-generation prompt to the engine and returns the first
/// line of the response, cleaned and trimmed. Falls back gracefully — all
/// errors are propagated to the caller, which applies the deterministic fallback.
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

        // Flatten the conversation into a single user turn so the prompt
        // always ends on `.user`, regardless of which role the conversation
        // itself last ended on (title generation is typically triggered
        // right after an assistant reply, so `messages.last` is usually
        // `.assistant`). This avoids relying on chat-template behavior for
        // a trailing assistant turn, which is undefined/fragile across
        // local model templates.
        let transcript = messages
            .map { "\(label(for: $0.role)): \($0.text)" }
            .joined(separator: "\n")
        let userTurn = Message(role: .user, text: transcript)

        var accumulated = ""
        for try await token in engine.generateResponse(for: [systemPrompt, userTurn], model: model) {
            accumulated += token
            // Stop collecting after we have enough for a title — avoids wasting inference
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