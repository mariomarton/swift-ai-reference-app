import Foundation

public enum PromptAccentColor: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case green
    case blue
    case indigo
    case orange
    case purple
    case red
    case teal

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .green:
            return L10n.Settings.accentColorGreen
        case .blue:
            return L10n.Settings.accentColorBlue
        case .indigo:
            return L10n.Settings.accentColorIndigo
        case .orange:
            return L10n.Settings.accentColorOrange
        case .purple:
            return L10n.Settings.accentColorPurple
        case .red:
            return L10n.Settings.accentColorRed
        case .teal:
            return L10n.Settings.accentColorTeal
        }
    }
}

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
    public var accentColor: PromptAccentColor

    public init(
        systemPrompt: String = Self.defaultSystemPrompt,
        customInstructions: String = "",
        tonePreset: PromptTonePreset = .none,
        accentColor: PromptAccentColor = .green
    ) {
        self.systemPrompt = systemPrompt
        self.customInstructions = customInstructions
        self.tonePreset = tonePreset
        self.accentColor = accentColor
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
