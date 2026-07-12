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
}
