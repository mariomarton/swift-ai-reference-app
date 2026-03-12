import XCTest
@testable import Czechoslovak_AI

final class FileBackedChatRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("messages.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testSaveAndLoadPersistsMessages() async throws {
        let repo = try FileBackedChatRepository(storageURL: fileURL, fileManager: FileManager.default)

        let msg1 = ChatMessage(role: .user, text: "Hello")
        try await repo.save(message: msg1)

        let loaded = try await repo.loadRecentMessages()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0], msg1)

        // Create a new repo instance pointing to same file to ensure persistence across instances
        let repo2 = try FileBackedChatRepository(storageURL: fileURL, fileManager: FileManager.default)
        let loaded2 = try await repo2.loadRecentMessages()
        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded2[0], msg1)
    }

    func testClearAllRemovesOnDisk() async throws {
        let repo = try FileBackedChatRepository(storageURL: fileURL, fileManager: FileManager.default)
        try await repo.save(message: ChatMessage(role: .user, text: "one"))
        try await repo.clearAll()

        let repo2 = try FileBackedChatRepository(storageURL: fileURL, fileManager: FileManager.default)
        let loaded = try await repo2.loadRecentMessages()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testConcurrentWritesAreSafe() async throws {
        let repo = try FileBackedChatRepository(storageURL: fileURL, fileManager: FileManager.default)
        let group = DispatchGroup()
        let queue = DispatchQueue.global()
        for i in 0..<10 {
            group.enter()
            queue.async {
                Task {
                    let msg = ChatMessage(role: .user, text: "m\(i)")
                    try? await repo.save(message: msg)
                    group.leave()
                }
            }
        }
        group.wait()

        let loaded = try await repo.loadRecentMessages()
        XCTAssertEqual(loaded.count, 10)
    }
}
