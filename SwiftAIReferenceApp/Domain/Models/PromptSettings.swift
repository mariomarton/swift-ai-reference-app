import Foundation

public enum PromptTonePreset: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none
    case concise
    case friendly
    case humorous

    public var id: String { rawValue }

    var instructionText: String? {
        switch self {
        case .none:
            return nil
        case .concise:
            return L10n.PromptSettings.toneConcise
        case .friendly:
            return L10n.PromptSettings.toneFriendly
        case .humorous:
            return L10n.PromptSettings.toneHumorous
        }
    }
}

public struct PromptSettings: Codable, Equatable, Sendable {
    public static var defaultSystemPrompt: String {
        L10n.PromptSettings.defaultSystemPrompt
    }

    static func normalizedSystemPrompt(_ prompt: String) -> String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var systemPrompt: String
    public var customInstructions: String
    public var tonePreset: PromptTonePreset

    public init(
        systemPrompt: String = Self.defaultSystemPrompt,
        customInstructions: String = "",
        tonePreset: PromptTonePreset = .none
    ) {
        self.systemPrompt = systemPrompt
        self.customInstructions = customInstructions
        self.tonePreset = tonePreset
    }

    public var effectiveSystemPrompt: String {
        let normalizedSystemPrompt = Self.normalizedSystemPrompt(systemPrompt)
        return normalizedSystemPrompt.isEmpty ? Self.defaultSystemPrompt : normalizedSystemPrompt
    }

    public var composedSystemPrompt: String {
        var sections: [String] = []

        sections.append(effectiveSystemPrompt)

        if let toneInstruction = tonePreset.instructionText {
            sections.append(toneInstruction)
        }

        let normalizedCustomInstructions = Self.normalizedSystemPrompt(customInstructions)
        if !normalizedCustomInstructions.isEmpty {
            sections.append(normalizedCustomInstructions)
        }

        return sections.joined(separator: "\n\n")
    }
}
