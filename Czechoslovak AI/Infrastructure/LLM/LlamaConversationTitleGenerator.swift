import Foundation

/// LLM-backed implementation of `ConversationTitleGenerator`.
///
/// Sends a short title-generation prompt to the engine and returns the first
/// line of the response, cleaned and trimmed. Falls back gracefully — all
/// errors are propagated to the caller, which applies the deterministic fallback.
public final class LlamaConversationTitleGenerator: ConversationTitleGenerator {

    private let engine: LLMEngine

    public init(engine: LLMEngine) {
        self.engine = engine
    }

    public func generateTitle(fromFirstUserMessage text: String, model: LLMModel?) async throws -> String? {
        let systemPrompt = Message(
            role: .system,
            text: "You are a chat title assistant. When given the user's first message, respond with only a short, descriptive title for the conversation — maximum 45 characters, no quotes, no punctuation at the end, same language as the user's message."
        )
        let prompt = Message(
            role: .user,
            text: text
        )

        var accumulated = ""
        for try await token in engine.generateResponse(for: [systemPrompt, prompt], model: model) {
            accumulated += token
            // Stop collecting after we have enough for a title — avoids wasting inference
            if accumulated.count > 200 { break }
        }

        let firstLine = accumulated
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return firstLine?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
