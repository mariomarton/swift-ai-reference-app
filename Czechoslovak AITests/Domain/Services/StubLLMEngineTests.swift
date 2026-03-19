import XCTest
@testable import Czechoslovak_AI

@MainActor
final class StubLLMEngineTests: XCTestCase {
    func testGeneratesStubbedResponseForLastUserMessage() async throws {
        let engine = StubLLMEngine()
        let userMsg = Message(role: .user, text: "Jak se máš?")
        let assistantMsg = try await engine.generateResponse(for: [userMsg], model: nil)
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertTrue(assistantMsg.text.contains("Jak se máš?"), "Stub should echo user message in response.")
    }

    func testGeneratesDefaultStubbedResponseWhenNoUserMessage() async throws {
        let engine = StubLLMEngine()
        let sysMsg = Message(role: .system, text: "Nějaká systémová zpráva")
        let assistantMsg = try await engine.generateResponse(for: [sysMsg], model: nil)
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertTrue(assistantMsg.text.contains("ukázková odpověď"), "Stub should return generic stubbed response.")
    }
}
