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
        XCTAssertEqual(engine.capturedMessages.count, 2)
        XCTAssertEqual(engine.capturedMessages[0].role, .system)
        XCTAssertEqual(engine.capturedMessages[0].text, "Custom title prompt")
        XCTAssertEqual(engine.capturedMessages[1].role, .user)
        XCTAssertTrue(engine.capturedMessages[1].text.contains("User: Kam na výlet?"))
        XCTAssertTrue(engine.capturedMessages[1].text.contains("Assistant: Do Tatier?"))
    }

    func testPromptEndsOnUserTurnWhenConversationEndsOnAssistant() async throws {
        // Title generation is typically triggered right after an assistant
        // reply, so the conversation's last message is usually `.assistant`.
        // The flattened transcript must still be sent as a single trailing
        // `.user` message, never leaving the assistant role as the last
        // entry in the array handed to the engine.
        let engine = CapturingConversationTitleEngine()
        engine.responseTokens = ["Trip planning"]
        let promptProvider = MockConversationTitlePromptProvider(titleSystemPrompt: "Custom title prompt")
        let generator = LlamaConversationTitleGenerator(engine: engine, promptProvider: promptProvider)

        _ = try await generator.generateTitle(
            fromConversationMessages: [
                Message(role: .user, text: "Kam na výlet?"),
                Message(role: .assistant, text: "Do Tatier?")
            ],
            model: nil
        )

        XCTAssertEqual(engine.capturedMessages.last?.role, .user)
    }

    func testPromptEndsOnUserTurnWhenConversationAlreadyEndsOnUser() async throws {
        // Even when the conversation already ends on `.user`, the generator
        // should still flatten everything into a single trailing `.user`
        // message rather than forwarding raw messages — confirming the
        // fix is a consistent flattening strategy, not a special case.
        let engine = CapturingConversationTitleEngine()
        engine.responseTokens = ["Trip planning"]
        let promptProvider = MockConversationTitlePromptProvider(titleSystemPrompt: "Custom title prompt")
        let generator = LlamaConversationTitleGenerator(engine: engine, promptProvider: promptProvider)

        _ = try await generator.generateTitle(
            fromConversationMessages: [
                Message(role: .assistant, text: "Kam bys chtěl jet?"),
                Message(role: .user, text: "Do Tatier.")
            ],
            model: nil
        )

        XCTAssertEqual(engine.capturedMessages.count, 2)
        XCTAssertEqual(engine.capturedMessages[0].role, .system)
        XCTAssertEqual(engine.capturedMessages[1].role, .user)
        XCTAssertTrue(engine.capturedMessages[1].text.contains("Assistant: Kam bys chtěl jet?"))
        XCTAssertTrue(engine.capturedMessages[1].text.contains("User: Do Tatier."))
    }
}