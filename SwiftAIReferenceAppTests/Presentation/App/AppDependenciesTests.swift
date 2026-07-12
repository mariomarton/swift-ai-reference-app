import Foundation
import XCTest

@testable import SwiftAIReferenceApp

final class AppDependenciesTests: XCTestCase {
    func testResolveModelPathFindsBundledModelInResourcesDirectory() throws {
        let resourcesURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resourcesURL) }

        let modelURL = resourcesURL.appendingPathComponent("model.gguf")
        try Data("test-model".utf8).write(to: modelURL)

        let resolvedPath = AppDependencies.resolveModelPath(resourceURL: resourcesURL)

        XCTAssertEqual(resolvedPath, modelURL.path)
    }

    func testMakeLLMEngineFallsBackToStubWhenModelIsMissing() {
        let result = AppDependencies.makeLLMEngine(
            modelPath: nil,
            isSimulator: false,
            isRunningTests: false
        )

        XCTAssertTrue(result.0 is StubLLMEngine)
        XCTAssertEqual(result.1, L10n.AppDependencies.startupWarningMissingModel)
    }

    func testMakeLLMEngineUsesInjectedEngineWhenModelLoads() throws {
        let expectedEngine = TestLLMEngine()

        let result = AppDependencies.makeLLMEngine(
            modelPath: "/tmp/model.gguf",
            isSimulator: false,
            isRunningTests: false,
            engineFactory: { _ in expectedEngine }
        )

        guard let actualEngine = result.0 as? TestLLMEngine else {
            return XCTFail("Expected injected test engine")
        }

        XCTAssertTrue(actualEngine === expectedEngine)
        XCTAssertNil(result.1)
    }

    func testMakeLLMEngineFallsBackToStubWhenModelFactoryThrows() {
        enum TestError: Error {
            case failed
        }

        let result = AppDependencies.makeLLMEngine(
            modelPath: "/tmp/model.gguf",
            isSimulator: false,
            isRunningTests: false,
            engineFactory: { _ in throw TestError.failed }
        )

        XCTAssertTrue(result.0 is StubLLMEngine)
        XCTAssertEqual(result.1, L10n.AppDependencies.startupWarningModelLoadFailed)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDependenciesTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class TestLLMEngine: LLMEngine {
    func generateResponse(for messages: [Message], model: LLMModel?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
