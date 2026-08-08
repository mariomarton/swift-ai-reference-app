import XCTest
@testable import SwiftAIReferenceApp

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testCurrentSettingsReflectAccentColorChangesImmediately() {
        let repository = MockPromptSettingsRepository()
        let viewModel = SettingsViewModel(repository: repository)

        XCTAssertEqual(viewModel.responseStylePickerIdentity, PromptAccentColor.green.rawValue)
        viewModel.accentColor = .teal

        XCTAssertEqual(viewModel.currentSettings.accentColor, .teal)
        XCTAssertEqual(viewModel.responseStylePickerIdentity, PromptAccentColor.teal.rawValue)
    }

    func testResetToDefaultsRestoresGreenAccentColor() {
        let repository = MockPromptSettingsRepository(
            initialSettings: PromptSettings(
                systemPrompt: "Custom",
                customInstructions: "Extra",
                tonePreset: .friendly,
                accentColor: .purple
            )
        )
        let viewModel = SettingsViewModel(repository: repository)

        viewModel.resetToDefaults()

        XCTAssertEqual(viewModel.accentColor, .green)
        XCTAssertEqual(viewModel.currentSettings.accentColor, .green)
        XCTAssertEqual(repository.savedSettings.last?.accentColor, .green)
    }
}

private final class MockPromptSettingsRepository: PromptSettingsRepository, @unchecked Sendable {
    private let initialSettings: PromptSettings
    private(set) var savedSettings: [PromptSettings] = []

    init(initialSettings: PromptSettings = PromptSettings()) {
        self.initialSettings = initialSettings
    }

    func loadSettings() -> PromptSettings {
        initialSettings
    }

    func saveSettings(_ settings: PromptSettings) {
        savedSettings.append(settings)
    }
}
