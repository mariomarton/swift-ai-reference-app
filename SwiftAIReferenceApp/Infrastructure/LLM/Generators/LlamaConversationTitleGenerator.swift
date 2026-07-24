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

    public func generateTitle(fromFirstUserMessage text: String, model: LLMModel?) async throws -> String? {
        let systemPrompt = Message(
            role: .system,
            text: promptProvider.titleSystemPrompt
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
