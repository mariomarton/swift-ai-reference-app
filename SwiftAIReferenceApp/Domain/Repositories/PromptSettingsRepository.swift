import Foundation

public protocol PromptSettingsRepository: Sendable {
    func loadSettings() -> PromptSettings
    func saveSettings(_ settings: PromptSettings)
}
