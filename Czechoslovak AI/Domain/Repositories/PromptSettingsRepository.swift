import Foundation

public protocol PromptSettingsRepository {
    func loadSettings() -> PromptSettings
    func saveSettings(_ settings: PromptSettings)
}
