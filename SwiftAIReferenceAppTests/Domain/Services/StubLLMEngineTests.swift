import XCTest
@testable import SwiftAIReferenceApp

@MainActor
final class StubLLMEngineTests: XCTestCase {
    func testGeneratesStubbedResponseForLastUserMessage() async throws {
        let engine = StubLLMEngine()
        let userMsg = Message(role: .user, text: "Jak se máš?")
        var collected = ""
        for try await token in engine.generateResponse(for: [userMsg], model: nil) {
            collected += token
        }
        XCTAssertTrue(collected.contains("Jak se máš?"), "Stub should echo user message in response.")
    }

    func testGeneratesDefaultStubbedResponseWhenNoUserMessage() async throws {
        let engine = StubLLMEngine()
        let sysMsg = Message(role: .system, text: "Nějaká systémová zpráva")
        var collected = ""
        for try await token in engine.generateResponse(for: [sysMsg], model: nil) {
            collected += token
        }
        XCTAssertTrue(collected.contains("ukážková odpoveď"), "Stub should return generic stubbed response.")
    }

    func testStubEmitsExactlyOneTokenThenFinishes() async throws {
        let engine = StubLLMEngine()
        let userMsg = Message(role: .user, text: "Test")
        var tokenCount = 0
        for try await _ in engine.generateResponse(for: [userMsg], model: nil) {
            tokenCount += 1
        }
        XCTAssertEqual(tokenCount, 1, "Stub should emit exactly one token")
    }
}
