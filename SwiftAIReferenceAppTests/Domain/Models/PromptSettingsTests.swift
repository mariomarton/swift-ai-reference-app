import XCTest
@testable import SwiftAIReferenceApp

final class PromptSettingsTests: XCTestCase {
    func testComposedSystemPromptFallsBackToDefaultWhenEmpty() {
        let settings = PromptSettings(systemPrompt: "   ", customInstructions: "", tonePreset: .none)

        XCTAssertEqual(settings.composedSystemPrompt, PromptSettings.defaultSystemPrompt)
    }

    func testComposedSystemPromptIncludesToneAndInstructions() {
        let settings = PromptSettings(
            systemPrompt: "Be helpful.",
            customInstructions: "Make your responses brief.",
            tonePreset: .concise
        )

        XCTAssertTrue(settings.composedSystemPrompt.contains("Be helpful."))
        XCTAssertTrue(settings.composedSystemPrompt.contains(L10n.PromptSettings.toneConcise))
        XCTAssertTrue(settings.composedSystemPrompt.contains("Make your responses brief."))
    }

    func testPromptSettingsDefaultsToGreenAccentColor() {
        XCTAssertEqual(PromptSettings().accentColor, .green)
    }

    func testAccentColorOptionsIncludeGreenAndRed() {
        XCTAssertTrue(PromptAccentColor.allCases.contains(.green))
        XCTAssertTrue(PromptAccentColor.allCases.contains(.red))
        XCTAssertFalse(PromptAccentColor.green.localizedTitle.isEmpty)
        XCTAssertFalse(PromptAccentColor.red.localizedTitle.isEmpty)
    }

    func testAccentColorOrderStartsWithGreenAndThenAlphabetical() {
        XCTAssertEqual(
            PromptAccentColor.allCases,
            [.green, .blue, .indigo, .orange, .purple, .red, .teal]
        )
    }
}
