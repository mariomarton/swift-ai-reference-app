import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var systemPrompt: String
    @Published var customInstructions: String
    @Published var tonePreset: PromptTonePreset

    private let repository: PromptSettingsRepository

    init(repository: PromptSettingsRepository) {
        self.repository = repository

        let settings = repository.loadSettings()
        systemPrompt = settings.systemPrompt
        customInstructions = settings.customInstructions
        tonePreset = settings.tonePreset
    }

    func save() {
        repository.saveSettings(currentSettings)
    }

    func resetToDefaults() {
        systemPrompt = PromptSettings.defaultSystemPrompt
        customInstructions = ""
        tonePreset = .none
        save()
    }

    var currentSettings: PromptSettings {
        PromptSettings(
            systemPrompt: systemPrompt,
            customInstructions: customInstructions,
            tonePreset: tonePreset
        )
    }
}
