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

    func testLoadConversationByID() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)

        let created = try await repo.createConversation(title: "Test Conversation")
        let loaded = try await repo.loadConversation(id: created.id)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, created.id)
        XCTAssertEqual(loaded?.title, "Test Conversation")
    }

    func testLoadNonexistentConversationReturnsNil() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)

        let loaded = try await repo.loadConversation(id: UUID())
        XCTAssertNil(loaded)
    }

    func testUpdateConversation() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)

        let created = try await repo.createConversation(title: "Original Title")
        var updated = created
        updated.title = "Updated Title"

        try await repo.updateConversation(updated)

        let reloaded = try await repo.loadConversation(id: created.id)
        XCTAssertEqual(reloaded?.title, "Updated Title")
    }

    func testPersistenceAcrossInstances() async throws {
        let repo1 = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let created = try await repo1.createConversation(title: "Persistent Conversation")

        let repo2 = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let loaded = try await repo2.loadConversation(id: created.id)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "Persistent Conversation")
    }

    func testDeleteConversationRemovesItFromListAndPersists() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let conv1 = try await repo.createConversation(title: "Keep")
        let conv2 = try await repo.createConversation(title: "Delete me")

        try await repo.deleteConversation(id: conv2.id)

        let listed = try await repo.listConversations()
        XCTAssertEqual(listed.count, 1)
        XCTAssertFalse(listed.contains(where: { $0.id == conv2.id }))
        XCTAssertTrue(listed.contains(where: { $0.id == conv1.id }))

        // Verify persistence across a fresh instance
        let repo2 = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        let listed2 = try await repo2.listConversations()
        XCTAssertEqual(listed2.count, 1)
        XCTAssertFalse(listed2.contains(where: { $0.id == conv2.id }))
    }

    func testDeleteNonexistentConversationThrows() async throws {
        let repo = try FileBackedConversationRepository(storageURL: fileURL, fileManager: FileManager.default)
        do {
            try await repo.deleteConversation(id: UUID())
            XCTFail("Expected throw for missing conversation")
        } catch {
            // expected
        }
    }
}
