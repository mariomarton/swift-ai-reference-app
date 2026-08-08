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
            tonePreset: .humorous,
            accentColor: .purple
        )

        repository.saveSettings(expected)

        XCTAssertEqual(repository.loadSettings(), expected)
    }

    func testSavingDefaultSystemPromptRemovesStoredOverride() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)
        repository.saveSettings(PromptSettings())

        XCTAssertNil(defaults.string(forKey: "promptSettings.systemPromptOverride"))
        XCTAssertNil(defaults.string(forKey: "promptSettings.systemPrompt"))
    }

    func testSavingDefaultSettingsStoresGreenAccentColor() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)
        repository.saveSettings(PromptSettings())

        XCTAssertEqual(defaults.string(forKey: "promptSettings.accentColor"), PromptAccentColor.green.rawValue)
    }

    func testLoadSettingsMigratesLegacySystemPromptOverride() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("Custom system", forKey: "promptSettings.systemPrompt")
        defaults.set("Extra instructions", forKey: "promptSettings.customInstructions")

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)

        XCTAssertEqual(
            repository.loadSettings(),
            PromptSettings(systemPrompt: "Custom system", customInstructions: "Extra instructions")
        )
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

    func testLoadSettingsFallsBackToDefaultAccentColorWhenStoredValueIsInvalid() {
        let suiteName = "prompt-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("not-a-color", forKey: "promptSettings.accentColor")

        let repository = UserDefaultsPromptSettingsRepository(defaults: defaults)

        XCTAssertEqual(repository.loadSettings().accentColor, .green)
    }
}
