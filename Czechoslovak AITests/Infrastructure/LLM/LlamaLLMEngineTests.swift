import XCTest
@testable import Czechoslovak_AI

/// Tests for `LlamaLLMEngine` that do **not** require a real GGUF model file.
///
/// Inference tests are intentionally omitted here — they belong in a separate
/// UI / integration test suite that has access to a bundled model artefact.
final class LlamaLLMEngineTests: XCTestCase {

    // MARK: - Init error paths

    func testInitThrowsModelNotFoundForNonExistentPath() throws {
        let bogusPath = "/tmp/nonexistent_model_\(UUID().uuidString).gguf"

        XCTAssertThrowsError(try LlamaLLMEngine(modelPath: bogusPath)) { error in
            guard case LlamaError.modelNotFound(let path) = error else {
                return XCTFail("Expected LlamaError.modelNotFound, got \(error)")
            }
            XCTAssertEqual(path, bogusPath)
        }
    }

    func testInitThrowsModelNotFoundForEmptyPath() {
        XCTAssertThrowsError(try LlamaLLMEngine(modelPath: "")) { error in
            guard case LlamaError.modelNotFound = error else {
                return XCTFail("Expected LlamaError.modelNotFound, got \(error)")
            }
        }
    }

    // MARK: - LlamaError: LocalizedError

    func testModelNotFoundHasNonEmptyDescription() {
        let error = LlamaError.modelNotFound(path: "/some/path.gguf")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testModelLoadFailedHasNonEmptyDescription() {
        let error = LlamaError.modelLoadFailed
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testUnsupportedModelArchitectureHasNonEmptyDescription() {
        let error = LlamaError.unsupportedModelArchitecture(description: "encoder-decoder model")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testContextCreationFailedHasNonEmptyDescription() {
        let error = LlamaError.contextCreationFailed
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testTokenizationFailedHasNonEmptyDescription() {
        let error = LlamaError.tokenizationFailed
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testInferenceFailedWrapsUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42, userInfo: nil)
        let error = LlamaError.inferenceFailed(underlying)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(error.errorDescription?.contains("42") ?? false,
                      "Description should surface the underlying error code")
    }

    // MARK: - Batching / context-window helpers

    func testPrefillChunkRangesSplitsIntoBatchSizedChunks() {
        let ranges = LlamaLLMEngine.prefillChunkRanges(totalTokens: 1200, batchSize: 512)
        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges[0], 0..<512)
        XCTAssertEqual(ranges[1], 512..<1024)
        XCTAssertEqual(ranges[2], 1024..<1200)
    }

    func testPrefillChunkRangesReturnsSingleChunkWhenFitsBatch() {
        let ranges = LlamaLLMEngine.prefillChunkRanges(totalTokens: 200, batchSize: 512)
        XCTAssertEqual(ranges, [0..<200])
    }

    func testTrimmedPromptStartIndexReturnsZeroWhenPromptFitsBudget() {
        let start = LlamaLLMEngine.trimmedPromptStartIndex(
            totalTokenCount: 1500,
            contextWindow: 4096,
            maxNewTokens: 1024
        )
        XCTAssertEqual(start, 0)
    }

    func testTrimmedPromptStartIndexDropsOldestTokensWhenPromptExceedsBudget() {
        let start = LlamaLLMEngine.trimmedPromptStartIndex(
            totalTokenCount: 4000,
            contextWindow: 4096,
            maxNewTokens: 1024
        )
        // Budget = 4096 - 1024 - 1 = 3071, trim = 4000 - 3071 = 929
        XCTAssertEqual(start, 929)
    }

    // MARK: - Prompt profile resolution

    func testResolvePromptTemplateProfileDefaultsToChatML() {
        let profile = LlamaLLMEngine.resolvePromptTemplateProfile(for: nil)
        assertProfile(profile, is: .chatML)
    }

    func testResolvePromptTemplateProfileUsesLlama3ForModelName() {
        let model = LLMModel(id: "local", name: "Llama-3.2-1B-Instruct", path: nil)
        let profile = LlamaLLMEngine.resolvePromptTemplateProfile(for: model)
        assertProfile(profile, is: .llama3)
    }

    func testResolvePromptTemplateProfileUsesLlama3ForModelPath() {
        let model = LLMModel(id: "local", name: "Custom", path: "/models/meta-llama-custom.gguf")
        let profile = LlamaLLMEngine.resolvePromptTemplateProfile(for: model)
        assertProfile(profile, is: .llama3)
    }

    func testInferPromptTemplateProfileFromLlama3ChatTemplate() {
        let template = "<|start_header_id|>assistant<|end_header_id|>"
        let profile = LlamaLLMEngine.inferPromptTemplateProfile(fromChatTemplate: template)
        assertOptionalProfile(profile, is: .llama3)
    }

    func testInferPromptTemplateProfileFromChatMLTemplate() {
        let template = "<|im_start|>assistant"
        let profile = LlamaLLMEngine.inferPromptTemplateProfile(fromChatTemplate: template)
        assertOptionalProfile(profile, is: .chatML)
    }

    func testResolvePromptTemplateProfilePrefersChatTemplateSignal() {
        let model = LLMModel(id: "local", name: "Llama-3.2", path: nil)
        let profile = LlamaLLMEngine.resolvePromptTemplateProfile(for: model, chatTemplate: "<|im_start|>assistant")
        assertProfile(profile, is: .chatML)
    }

    // MARK: - Stream output policy

    func testProcessPiecesForTestingStopsAtChatMLStopSequence() {
        let result = LlamaLLMEngine.processPiecesForTesting(
            pieces: [
                "Hlavne mesto Slovenska je Bratislava.",
                "<|im_",
                "start|>assistant"
            ],
            profile: .chatML
        )

        XCTAssertTrue(result.didStop)
        XCTAssertEqual(result.output, "Hlavne mesto Slovenska je Bratislava.")
    }

    func testProcessPiecesForTestingStripsControlMarkersFromOutput() {
        let result = LlamaLLMEngine.processPiecesForTesting(
            pieces: [
                "Ahoj ",
                "<|im_start|>assistant",
                "svet"
            ],
            profile: .chatML
        )

        XCTAssertTrue(result.didStop)
        XCTAssertEqual(result.output, "Ahoj ")
    }

    func testProcessPiecesForTestingStopsAtLlama3Boundary() {
        let result = LlamaLLMEngine.processPiecesForTesting(
            pieces: [
                "Praha je hlavne mesto Ceskej republiky.",
                "<|eot_id|><|start_header_id|>user<|end_header_id|>"
            ],
            profile: .llama3
        )

        XCTAssertTrue(result.didStop)
        XCTAssertEqual(result.output, "Praha je hlavne mesto Ceskej republiky.")
    }

    func testProcessPiecesForTestingStopsOnRepeatedLongSpan() {
        let repeatedSentence = "Bratislava je hlavne mesto Slovenska a je centrom kultury a historie. "

        let result = LlamaLLMEngine.processPiecesForTesting(
            pieces: Array(repeating: repeatedSentence, count: 5),
            profile: .chatML
        )

        XCTAssertTrue(result.didStop)
        let fullRepetition = String(repeating: repeatedSentence, count: 5)
        XCTAssertFalse(result.output.contains(fullRepetition))
    }

    func testProcessPiecesForTestingDoesNotStopForNonLoopingLongOutput() {
        let result = LlamaLLMEngine.processPiecesForTesting(
            pieces: [
                "Bratislava je hlavne mesto Slovenska s bohatou historiou a kulturou. ",
                "Mesto je zname hradom, Dunajom a historickym centrom. ",
                "Dnes je Bratislava politickym, kulturnym a ekonomickym jadrom krajiny."
            ],
            profile: .chatML
        )

        XCTAssertFalse(result.didStop)
        XCTAssertFalse(result.output.isEmpty)
    }

    // MARK: - Sampling defaults

    func testDefaultSamplingConfigUsesConservativeAntiLoopValues() {
        let config = LlamaLLMEngine.defaultSamplingConfig()

        XCTAssertEqual(config.topK, 40)
        XCTAssertEqual(config.topP, 0.95, accuracy: 0.0001)
        XCTAssertEqual(config.minP, 0.05, accuracy: 0.0001)
        XCTAssertEqual(config.minKeep, 1)
        XCTAssertEqual(config.temperature, 0.8, accuracy: 0.0001)

        XCTAssertEqual(config.penaltyLastN, 128)
        XCTAssertEqual(config.penaltyRepeat, 1.15, accuracy: 0.0001)
        XCTAssertEqual(config.penaltyFrequency, 0.05, accuracy: 0.0001)
        XCTAssertEqual(config.penaltyPresence, 0.05, accuracy: 0.0001)
    }

    // MARK: - Test helpers

    private func assertProfile(
        _ actual: LlamaLLMEngine.PromptTemplateProfile,
        is expected: LlamaLLMEngine.PromptTemplateProfile,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (actual, expected) {
        case (.chatML, .chatML), (.llama3, .llama3):
            return
        default:
            XCTFail("Expected \(expected) but got \(actual)", file: file, line: line)
        }
    }

    private func assertOptionalProfile(
        _ actual: LlamaLLMEngine.PromptTemplateProfile?,
        is expected: LlamaLLMEngine.PromptTemplateProfile,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected non-nil profile", file: file, line: line)
            return
        }
        assertProfile(actual, is: expected, file: file, line: line)
    }
}
