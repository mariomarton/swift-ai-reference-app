import XCTest
@testable import SwiftAIReferenceApp

private struct MockConversationTitlePromptProvider: ConversationTitlePromptProviding {
    let titleSystemPrompt: String
}

private final class CapturingConversationTitleEngine: LLMEngine {
    private(set) var capturedMessages: [Message] = []
    private(set) var capturedModel: LLMModel?
    var responseTokens: [String] = []

    func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        capturedMessages = messages
        capturedModel = model
        let tokens = responseTokens
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }
}

@MainActor
final class LlamaConversationTitleGeneratorTests: XCTestCase {
    func testUsesInjectedPromptProvider() async throws {
        let engine = CapturingConversationTitleEngine()
        engine.responseTokens = ["Weekend plans"]
        let promptProvider = MockConversationTitlePromptProvider(titleSystemPrompt: "Custom title prompt")
        let generator = LlamaConversationTitleGenerator(engine: engine, promptProvider: promptProvider)

        let title = try await generator.generateTitle(
            fromConversationMessages: [
                Message(role: .user, text: "Kam na výlet?"),
                Message(role: .assistant, text: "Do Tatier?")
            ],
            model: nil
        )

        XCTAssertEqual(title, "Weekend plans")
        XCTAssertEqual(engine.capturedMessages.count, 3)
        XCTAssertEqual(engine.capturedMessages.first?.role, .system)
        XCTAssertEqual(engine.capturedMessages.first?.text, "Custom title prompt")
        XCTAssertEqual(engine.capturedMessages.last?.role, .user)
        XCTAssertEqual(engine.capturedMessages[1].text, "Kam na výlet?")
        XCTAssertEqual(engine.capturedMessages[2].text, "Do Tatier?")
    }
}
