import Foundation

/// Converts a `[Message]` history into a ChatML-formatted prompt string.
///
/// ChatML is used by Phi-3 / Phi-3.5, Mistral-instruct, OpenChat, and other
/// compatible GGUF models.  The format looks like:
///
/// ```
/// <|im_start|>system
/// You are a helpful assistant.<|im_end|>
/// <|im_start|>user
/// Hello!<|im_end|>
/// <|im_start|>assistant
/// Hi there!<|im_end|>
/// <|im_start|>assistant
/// ```  ← model continues from here
///
/// For Llama-3 models, use `Llama3Formatter` instead (different header tokens).
struct ChatMLFormatter {

    /// Injected when the message history contains no system turn.
    nonisolated static let defaultSystemPrompt = "Si užitočný asistent. Odpovedaj jasne a stručne."

    /// Formats `messages` into a ready-to-tokenise prompt string.
    /// A trailing `<|im_start|>assistant\n` is appended so the model knows
    /// it should produce the next assistant turn.
    nonisolated static func format(_ messages: [Message]) -> String {
        var result = ""

        let hasSystemTurn = messages.first?.role == .system
        if !hasSystemTurn {
            result += turn(role: "system", content: defaultSystemPrompt)
        }

        for message in messages {
            result += turn(role: roleName(for: message.role), content: message.text)
        }

        // Open the assistant turn — the model generates from here
        result += "<|im_start|>assistant\n"
        return result
    }

    // MARK: - Private helpers

    nonisolated private static func turn(role: String, content: String) -> String {
        "<|im_start|>\(role)\n\(content)<|im_end|>\n"
    }

    nonisolated private static func roleName(for role: Message.Role) -> String {
        switch role {
        case .user:      return "user"
        case .assistant: return "assistant"
        case .system:    return "system"
        }
    }
}
