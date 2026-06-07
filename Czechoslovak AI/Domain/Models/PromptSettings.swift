import Foundation

public enum PromptTonePreset: String, Codable, CaseIterable, Identifiable, Hashable {
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
            return "Answer briefly and directly."
        case .friendly:
            return "Use a warm, friendly tone."
        case .humorous:
            return "Add light, tasteful humor when appropriate."
        }
    }
}

public struct PromptSettings: Codable, Equatable {
    public static let defaultSystemPrompt = "Si užitočný asistent. Odpovedaj jasne a stručne."

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

    public var composedSystemPrompt: String {
        var sections: [String] = []

        let normalizedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        sections.append(normalizedSystemPrompt.isEmpty ? Self.defaultSystemPrompt : normalizedSystemPrompt)

        if let toneInstruction = tonePreset.instructionText {
            sections.append(toneInstruction)
        }

        let normalizedCustomInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedCustomInstructions.isEmpty {
            sections.append(normalizedCustomInstructions)
        }

        return sections.joined(separator: "\n\n")
    }
}
