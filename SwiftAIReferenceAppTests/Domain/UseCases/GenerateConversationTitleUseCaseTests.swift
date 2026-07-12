import XCTest
@testable import SwiftAIReferenceApp

private enum GeneratorStubError: Error {
    case failed
}

private final class MockConversationTitleGenerator: ConversationTitleGenerator {
    var generatedTitle: String?
    var shouldThrow = false
    private(set) var invocationCount = 0
    private(set) var capturedInput: String?

    func generateTitle(fromFirstUserMessage text: String, model: LLMModel?) async throws -> String? {
        invocationCount += 1
        capturedInput = text
        if shouldThrow {
            throw GeneratorStubError.failed
        }
        return generatedTitle
    }
}

@MainActor
final class GenerateConversationTitleUseCaseTests: XCTestCase {
    func testReturnsNilWhenExistingTitleIsNonEmpty() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "Ignored"
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: "Manual title",
            firstUserMessageText: "Ako funguje da\u{148} v s.r.o.?",
            model: nil
        )

        XCTAssertNil(result)
        XCTAssertEqual(generator.invocationCount, 0)
    }

    func testReturnsGeneratedTitleWhenValid() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "DPH povinnosti pre s.r.o."
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "Ako funguje da\u{148} v s.r.o.?",
            model: nil
        )

        XCTAssertEqual(result, "DPH povinnosti pre s.r.o.")
        XCTAssertEqual(generator.invocationCount, 1)
    }

    func testNormalizesGeneratedTitle() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "  \"  DPH\n povinnosti pre   s.r.o.  \"  "
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "Ahoj",
            model: nil
        )

        XCTAssertEqual(result, "DPH povinnosti pre s.r.o.")
    }

    func testFallsBackToFirstSentenceWhenGeneratorThrows() async {
        let generator = MockConversationTitleGenerator()
        generator.shouldThrow = true
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "Potrebujem poradit s danou. Co mam podat najskor?",
            model: nil
        )

        XCTAssertEqual(result, "Potrebujem poradit s danou.")
        XCTAssertEqual(generator.invocationCount, 1)
    }

    func testFallsBackToFirstNonEmptyLineWhenNoSentenceBoundary() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "   "
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "\n\nRozpis odvodov pre SZCO\nDruhy riadok",
            model: nil
        )

        XCTAssertEqual(result, "Rozpis odvodov pre SZCO")
    }

    func testClipsToFortyFiveCharacters() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "Toto je velmi dlhy nazov konverzacie, ktory ma byt skrateny na limit"
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "Ahoj",
            model: nil
        )

        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result?.count ?? 0, DefaultGenerateConversationTitleUseCase.maxTitleLength)
        XCTAssertEqual(result, "Toto je velmi dlhy nazov konverzacie, ktory")
    }

    func testReturnsNilWhenInputMessageIsBlank() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "X"
        let useCase = DefaultGenerateConversationTitleUseCase(generator: generator)

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "   \n\n   ",
            model: nil
        )

        XCTAssertNil(result)
        XCTAssertEqual(generator.invocationCount, 0)
    }

    func testReturnsNilForUnsupportedTriggerPolicy() async {
        let generator = MockConversationTitleGenerator()
        generator.generatedTitle = "X"
        let useCase = DefaultGenerateConversationTitleUseCase(
            generator: generator,
            triggerPolicy: .afterEachMessage
        )

        let result = await useCase.execute(
            existingTitle: nil,
            firstUserMessageText: "Ahoj",
            model: nil
        )

        XCTAssertNil(result)
        XCTAssertEqual(generator.invocationCount, 0)
    }
}
