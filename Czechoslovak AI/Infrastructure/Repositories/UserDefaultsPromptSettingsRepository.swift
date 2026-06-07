import Foundation

public final class UserDefaultsPromptSettingsRepository: PromptSettingsRepository {
    private let defaults: UserDefaults

    private enum Keys {
        static let systemPrompt = "promptSettings.systemPrompt"
        static let customInstructions = "promptSettings.customInstructions"
        static let tonePreset = "promptSettings.tonePreset"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSettings() -> PromptSettings {
        let systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? PromptSettings.defaultSystemPrompt
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
        defaults.set(settings.systemPrompt, forKey: Keys.systemPrompt)
        defaults.set(settings.customInstructions, forKey: Keys.customInstructions)
        defaults.set(settings.tonePreset.rawValue, forKey: Keys.tonePreset)
    }
}
