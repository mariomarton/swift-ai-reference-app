import Foundation

public enum ConversationTitleTriggerPolicy: Equatable {
    case firstMessageOnly
    case afterEachMessage
}

public protocol GenerateConversationTitleUseCase {
    /// Returns a normalized title or nil when no title should be set.
    /// This use case never overwrites existing titles.
    func generateTitle(existingTitle: String?, firstUserMessageText: String, model: LLMModel?) async -> String?
}

public final class DefaultGenerateConversationTitleUseCase: GenerateConversationTitleUseCase {
    public static let maxTitleLength = 45

    private let generator: ConversationTitleGenerator
    private let triggerPolicy: ConversationTitleTriggerPolicy

    public init(
        generator: ConversationTitleGenerator,
        triggerPolicy: ConversationTitleTriggerPolicy = .firstMessageOnly
    ) {
        self.generator = generator
        self.triggerPolicy = triggerPolicy
    }

    public func generateTitle(existingTitle: String?, firstUserMessageText: String, model: LLMModel?) async -> String? {
        guard triggerPolicy == .firstMessageOnly else {
            return nil
        }

        if Self.hasNonEmptyTitle(existingTitle) {
            return nil
        }

        // rawInput preserves newline structure so fallback can split by lines.
        let rawInput = firstUserMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = Self.collapseWhitespace(in: rawInput)
        guard !normalizedInput.isEmpty else {
            return nil
        }

        do {
            let generated = try await generator.generateTitle(fromFirstUserMessage: normalizedInput, model: model)
            if let validGenerated = Self.normalizeOutput(generated) {
                return validGenerated
            }
        } catch {
            // Intentionally ignored. We always attempt deterministic fallback.
        }

        return Self.fallbackTitle(from: rawInput)
    }

    private static func hasNonEmptyTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizeInput(_ text: String) -> String {
        collapseWhitespace(in: text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeOutput(_ text: String?) -> String? {
        guard let text else { return nil }

        var normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        normalized = stripWrappingQuotes(from: normalized)
        normalized = collapseWhitespace(in: normalized)

        guard !normalized.isEmpty else {
            return nil
        }

        return clipped(normalized, maxLength: maxTitleLength)
    }

    private static func fallbackTitle(from text: String) -> String? {
        let sentence = firstSentence(from: text) ?? firstNonEmptyLine(from: text)
        guard let sentence else { return nil }

        let normalized = normalizeOutput(sentence)
        return normalized
    }

    private static func firstSentence(from text: String) -> String? {
        let scalars = Array(text)
        guard !scalars.isEmpty else { return nil }

        for idx in scalars.indices {
            let char = scalars[idx]
            if char == "." || char == "!" || char == "?" {
                let candidate = String(scalars[...idx])
                let normalized = collapseWhitespace(in: candidate).trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty {
                    return normalized
                }
            }
        }

        return nil
    }

    private static func firstNonEmptyLine(from text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let normalized = collapseWhitespace(in: line).trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return normalized
            }
        }

        return nil
    }

    private static func stripWrappingQuotes(from text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotePairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("„", "“"),
            ("\u{201C}", "\u{201D}")
        ]

        var removed = true
        while removed, value.count >= 2 {
            removed = false
            for pair in quotePairs {
                if value.first == pair.0, value.last == pair.1 {
                    value.removeFirst()
                    value.removeLast()
                    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    removed = true
                    break
                }
            }
        }

        return value
    }

    private static func collapseWhitespace(in text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func clipped(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }

        let hardCut = String(text.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastSpace = hardCut.lastIndex(of: " "), lastSpace != hardCut.startIndex {
            let candidate = hardCut[..<lastSpace].trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return String(candidate)
            }
        }

        return hardCut
    }
}
