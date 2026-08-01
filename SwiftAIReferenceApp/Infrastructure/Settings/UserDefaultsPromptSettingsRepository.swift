import Foundation

public final class UserDefaultsPromptSettingsRepository: PromptSettingsRepository, @unchecked Sendable {
    private let defaults: UserDefaults

    private enum Keys {
        static let systemPromptOverride = "promptSettings.systemPromptOverride"
        static let legacySystemPrompt = "promptSettings.systemPrompt"
        static let customInstructions = "promptSettings.customInstructions"
        static let tonePreset = "promptSettings.tonePreset"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSettings() -> PromptSettings {
        let systemPrompt: String
        if let override = defaults.string(forKey: Keys.systemPromptOverride) {
            systemPrompt = PromptSettings.normalizedSystemPrompt(override).isEmpty
                ? PromptSettings.defaultSystemPrompt
                : override
        } else if let legacySystemPrompt = defaults.string(forKey: Keys.legacySystemPrompt) {
            let normalizedLegacySystemPrompt = PromptSettings.normalizedSystemPrompt(legacySystemPrompt)
            let normalizedDefaultSystemPrompt = PromptSettings.normalizedSystemPrompt(PromptSettings.defaultSystemPrompt)
            systemPrompt = normalizedLegacySystemPrompt == normalizedDefaultSystemPrompt
                ? PromptSettings.defaultSystemPrompt
                : legacySystemPrompt
        } else {
            systemPrompt = PromptSettings.defaultSystemPrompt
        }

        let customInstructions = defaults.string(forKey: Keys.customInstructions) ?? ""

        let tonePreset = PromptTonePreset(
            rawValue: defaults.string(forKey: Keys.tonePreset) ?? PromptTonePreset.none.rawValue
        ) ?? .none

        return PromptSettings(
            systemPrompt: systemPrompt,
            customInstructions: customInstructions,
            tonePreset: tonePreset
        )
    }

    public func saveSettings(_ settings: PromptSettings) {
        let normalizedSystemPrompt = PromptSettings.normalizedSystemPrompt(settings.systemPrompt)
        let normalizedDefaultSystemPrompt = PromptSettings.normalizedSystemPrompt(PromptSettings.defaultSystemPrompt)

        if normalizedSystemPrompt.isEmpty || normalizedSystemPrompt == normalizedDefaultSystemPrompt {
            defaults.removeObject(forKey: Keys.systemPromptOverride)
            defaults.removeObject(forKey: Keys.legacySystemPrompt)
        } else {
            defaults.set(settings.systemPrompt, forKey: Keys.systemPromptOverride)
            defaults.removeObject(forKey: Keys.legacySystemPrompt)
        }

        defaults.set(settings.customInstructions, forKey: Keys.customInstructions)
        defaults.set(settings.tonePreset.rawValue, forKey: Keys.tonePreset)
    }
}
