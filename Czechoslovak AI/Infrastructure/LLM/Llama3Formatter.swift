import Foundation

/// Converts a `[Message]` history into a Llama-3-instruct formatted prompt string.
///
/// Llama-3 instruct format looks like:
/// <|begin_of_text|><|start_header_id|>system<|end_header_id|>
///
/// You are a helpful assistant.<|eot_id|>
/// <|start_header_id|>user<|end_header_id|>
///
/// Hello!<|eot_id|>
/// <|start_header_id|>assistant<|end_header_id|>
///
struct Llama3Formatter {

    nonisolated static let defaultSystemPrompt = "Si užitočný asistent. Odpovedaj jasne a stručne."

    nonisolated static func format(_ messages: [Message]) -> String {
        var result = "<|begin_of_text|>"

        let hasSystemTurn = messages.first?.role == .system
        if !hasSystemTurn {
            result += turn(role: "system", content: defaultSystemPrompt)
        }

        for message in messages {
            result += turn(role: roleName(for: message.role), content: message.text)
        }

        // Open assistant turn for next-token continuation.
        result += "<|start_header_id|>assistant<|end_header_id|>\n\n"
        return result
    }

    nonisolated private static func turn(role: String, content: String) -> String {
        "<|start_header_id|>\(role)<|end_header_id|>\n\n\(content)<|eot_id|>"
    }

    nonisolated private static func roleName(for role: Message.Role) -> String {
        switch role {
        case .user:      return "user"
        case .assistant: return "assistant"
        case .system:    return "system"
        }
    }
}
