import XCTest
@testable import Czechoslovak_AI

@MainActor
final class FileBackedConversationRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("conversations.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testCreateAndListPersistsConversations() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)

        let conv1 = try await repo.createConversation(title: "Test 1")
        let conv2 = try await repo.createConversation(title: "Test 2")

        let loaded = try await repo.listConversations()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains(where: { $0.id == conv1.id }))
        XCTAssertTrue(loaded.contains(where: { $0.id == conv2.id }))

        // Create a new repo instance pointing to same file to ensure persistence across instances
        let repo2 = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let loaded2 = try await repo2.listConversations()
        XCTAssertEqual(loaded2.count, 2)
        XCTAssertTrue(loaded2.contains(where: { $0.id == conv1.id }))
        XCTAssertTrue(loaded2.contains(where: { $0.id == conv2.id }))
    }

    func testConversationsAreSortedByUpdatedAt() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        _ = try await repo.createConversation(title: "A")
        // Simulate a later update
        sleep(1)
        let conv2 = try await repo.createConversation(title: "B")
        let loaded = try await repo.listConversations()
        XCTAssertEqual(loaded.first?.id, conv2.id)
    }

    func testInitWithMissingFileDoesNotThrow() async throws {
        // File does not exist yet
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let loaded = try await repo.listConversations()
        XCTAssertTrue(loaded.isEmpty)
    }
}
