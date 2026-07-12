import XCTest
@testable import SwiftAIReferenceApp

@MainActor
final class UserDefaultsPromptSettingsRepositoryTests: XCTestCase {
    func testRoundTripsSavedSettings() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)
        let expected = PromptSettings(
            systemPrompt: "Custom system",
            customInstructions: "Extra instructions",
            tonePreset: .humorous
        )

        repository.saveSettings(expected)

        XCTAssertEqual(repository.loadSettings(), expected)
    }

    func testLoadSettingsReturnsDefaultsWhenNothingWasSaved() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)

        XCTAssertEqual(repository.loadSettings(), PromptSettings())
    }
}
