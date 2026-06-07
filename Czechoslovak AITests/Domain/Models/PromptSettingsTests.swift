import XCTest
@testable import Czechoslovak_AI

final class PromptSettingsTests: XCTestCase {
    func testComposedSystemPromptFallsBackToDefaultWhenEmpty() {
        let settings = PromptSettings(systemPrompt: "   ", customInstructions: "", tonePreset: .none)

        XCTAssertEqual(settings.composedSystemPrompt, PromptSettings.defaultSystemPrompt)
    }

    func testComposedSystemPromptIncludesToneAndInstructions() {
        let settings = PromptSettings(
            systemPrompt: "Be helpful.",
            customInstructions: "Prefer Czech.",
            tonePreset: .concise
        )

        XCTAssertTrue(settings.composedSystemPrompt.contains("Be helpful."))
        XCTAssertTrue(settings.composedSystemPrompt.contains("Answer briefly and directly."))
        XCTAssertTrue(settings.composedSystemPrompt.contains("Prefer Czech."))
    }
}
